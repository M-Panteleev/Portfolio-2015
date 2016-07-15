// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

//****************************************************************************
// Скрипт сервиса-планировщика.
//****************************************************************************
// Назначение:
//	1) запуск синхронизации таблицы "macHeap" между linked-серверами.
// 	   "macHeap" - таблица терриконов (содержит: названия, массы, химический состав и другие параметры).
//
// 	2) запуск механизма проверки и пересчёта параметров терриконов исходя из выполненных операций.
//****************************************************************************

#include <odbc>       // Библиотека для работы с серверами и БД.
#include <query>      // Библиотека для выполнения запросов.
#include "aks_com.js" // Объявление глобальных переменных, узлов, серверов, функции и прочего.
#include "prs.js"     // Объявление функций отвечающих за парсинг данных. 

// Функция синхронизации терриконов (вызывается из функции "syncHeapAll" см. ниже)
function syncHeap(src,dest,withInsert)
{
	// Добавил: Пантелеев М.Ю.
	// Дата:    19.02.2015г. 
	// Пересчёт, проверка и обновление значений "nWeight" и "xValueProbe" таблицы "macHeap" для терриконов, 
	// хим. анализ или масса которых отличаются от расчётных (BTS:****). 
	
	if (src == nodePrimary) // Если источником синхронизации является узел Главного сервера,
	// значит, после текущего IF будет выполняться раздача данных из таблицы "macHeap" 
	// на другие linked-сервера. До запуска раздачи выполняем проверку содержимого 
	// некоторых полей таблицы, а именно: масс и химического состава терриконов.
	// В случае обнаружения отличий массы и хим. состава террикона в "macHeap" и 
	// рассчитанными массой и хим. составом согласно выполненных операций (из табл."macHeapHistory") - 
	// выполняется обновление значений в таблице "macHeap" (см. ХП "AlterMacHeap" на Главном сервере).
	{
		// Проверка соединения.
		if (!srcQuery.connect(src.name)) 
		{
			throwError ("CONNECT to" + src.link + " :" + srcQuery.lastError());
			return;
		}
		//Объявление переменной содержащей вызов ХП.
		var SQLQuery = '\n EXEC dbo.AlterMacHeap \n'
		
		// Запуск процедуры "AlterMacHeap" на Главном сервере. 
		if (!srcQuery.open(SQLQuery)) 
		{
			// Если ХП не найдена, либо при выполнении возникли ошибки 
			// производится запись соответствующего сообщения в системный лог планировщика.
			throwError('ERROR. Script: "syncHeap_aksu.js". \n'+
						'На сервере ['+src.link + '] возникла ошибка при выполнении хранимой процедуры '+
						'"AlterMacHeap"! \n Данная хранимая процедура выполняет функцию пересчёта значений '+
						'"nWeight" и "xValueProbe" в таблице "macHeap". \n Пересчёт осуществляется в случае '+
						'обнаружения отличий между массой и хим. составом террикона в "macHeap" и \n'+
						'рассчитанными параметрами, согласно выполненных движений. \n'
					   );
			return;
		}		
	}
	
    // -------------------------------
    // Участок ниже, отвечает за синхронизацию таблицы "macHeap".
    // -------------------------------
	
    // Имя синхронизируемой таблицы.
    var cTableName = 'macHeap';
    // Первичный ключ.
    var pkFileld = 'nGUID';
	
    // Выборка всех записей из базы-источника.
    var selectAllQuery = "EXEC dbo.selectHeapForSync";
    // Выборка одной конкретной записи из базы-приемника.
    var chkExistsQuery = "EXEC dbo.selectHeapForSync @nGUID = ':nGUID'";
    // Вставка в базу-приемник.
    var insertQuery = "EXEC dbo.insertHeapBySync @nGUID = :nGUID, @cNameHeap = :cNameHeap, @nUnitId = :nUnitId, " + 
					        "@nOwnerId = :nOwnerId, @dDateCreate = :dDateCreate, @dDateClose = :dDateClose, " +
                      				"@nMaterialId = :nMaterialId, @nFractionId = :nFractionId, @nWeight = :nWeight, " +
					  	"@xValueProbe = :xValueProbe, @cNote = :cNote, @dLastEdit = :dLastEdit";
    // Обновление записи в базе-приемнике.
    var updateQuery = "EXEC dbo.updateHeapBySync @nGUID = :nGUID, @cNameHeap = :cNameHeap, @nUnitId = :nUnitId, "+
					  	"@nOwnerId = :nOwnerId, @dDateCreate = :dDateCreate, @dDateClose = :dDateClose, "+
					  	"@nMaterialId = :nMaterialId, @nFractionId = :nFractionId, @nWeight = :nWeight, "+ 
					  	"@xValueProbe = :xValueProbe, @cNote = :cNote, @dLastEdit = :dLastEdit";
    
    // Вывод на экран сообщения с параметрами текущего процесса (просматривается во время запуска скрипта в отладчике).
    print(src.link+' -->> '+dest.link);
    
    // Запуск функции из "aks_com.js".
    // Функция осуществляет запуск SQL-запросов, парсинг, проверки и ещё много чего... 
    CoreSync(src,dest,withInsert,cTableName,pkFileld,selectAllQuery,chkExistsQuery,insertQuery,updateQuery);
}

// Главная функция текущего скрипта(вызывается первой). 
function syncHeapAll()
{
    // Краткое пояснение.
    // ------------------------
    // Согласно декларации в "aks_com.js":
    //
    // 		1) переменная "NodePool" - пул абонентов.
    //		   var NodePool = new Array();  
    // 		2) Прототип узла имеет вид:
    //		   function Node(servrName, dbName, conString, conName, conDriver, lnkCode)
    //		   {...}
    // 		3) Наполнение пула абонентов узлами происходит так:
    //		   if (node.connect()) NodePool.push(nodeName);

    // Передача данных с linked-серверов Главному серверу.
    var i = 0;
    while (NodePool[i] != undefined)
    {
      syncHeap(NodePool[i],nodePrimary,true);  // См. функцию "syncHeap" выше.
      i++;
    }
    
    // Передача данных от Главного сервера linked-серверам.
    i = 0;
    while (NodePool[i] != undefined)
    {
      syncHeap(nodePrimary,NodePool[i],true);  // См. функцию "syncHeap" выше.
      i++;
    }
    
    // Закрытие соединений с источником и приёмником
    srcQuery.close();
    destQuery.close();
}

// -------------------------------
// БЛОК ЗАПУСКА текущего скрипта.
// -------------------------------
// Установка соединений с серверами (массивом абонентов "NodePool" и узлом Главного сервера "nodePrimary").
syncStart('Heap_Local');
// Запуск главной функции.
syncHeapAll();
// Закрытие соединений с серверами (массивом абонентов "NodePool" и узлом Главного сервера "nodePrimary").
syncDone();
// Сообщение ниже будет в системном логе в случае нормального завершения скрипта.
logMess = 'Script "syncHeap.js" execition success';

