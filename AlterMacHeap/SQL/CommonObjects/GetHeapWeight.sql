--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('GetHeapWeight') IS NOT NULL
	DROP PROCEDURE dbo.GetHeapWeight
GO
-->*********************************************************************************************<--
--> Процедура осуществляет:
-->  1) расчёт веса терриконов;
-->  2) расчёт средневзвешенного хим. анализа терриконов;
-->  3) сортировку хим. анализа движений терриконов в соответствии с порядком следования хим. компонентов.
--> Результат выполнения ХП передаётся по линку в таблицу "macGetHeapWeightResult" на Главном сервере.

--> Автор: Пантелеев М.Ю.
--> Дата:  21.01.2015г.
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.GetHeapWeight 

AS
BEGIN TRY

	DECLARE 
		@SQL		 NVARCHAR(MAX),
		@cDB_Name	 NVARCHAR (20) =  DB_NAME(), --| Имя текущей БД.
		@nLocationId	 INT,		 --| Id местоположения террикона.
		@nRowCountModif	 INT,		 --| Количество движений террикона, отсортированных в 
						 --| соответствии с порядком следования хим. компонентов;
		@nHeapWeight	 DECIMAL(9,3),   --| Масса террикона рассчитанная исходя из выполненных движений.
		@dDateEvent	 DATETIME,	 --| Дата последней операции "Зачистки" либо "Замера" террикона. 
		@dLastEditOp	 DATETIME,	 --| Дата последнего движения террикона. 
		@nSumWeight_In	 DECIMAL(9,3),   --| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
		@nSumWeight_Out	 DECIMAL(9,3),   --| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
		@cHeapValueProbe NVARCHAR(MAX)   --| Средневзвешенный хим. анализ террикона.

	 
	--| Переменная "@nLocationId" используется в запросе ниже, для получения только тех терриконов,
	--| местом хранения которых является текущий цех.
	--| Если запрос выполняется на Главном сервере - в выборку попадут терриконы,
	--| расположенные на плащадке "Завод" (nUnitId = 152).
	SET @nLocationId =
			CASE 
				WHEN @cDB_Name = 'MasterDB'	THEN 152
				WHEN @cDB_Name = 'Plant1' THEN 5
				WHEN @cDB_Name = 'Plant2' THEN 7
				WHEN @cDB_Name = 'Plant4' THEN 8
				WHEN @cDB_Name = 'Plant6' THEN 9
			END 
	
	--| Удаление временных таблиц, если по каким-либо причинам 
	--| они не были удалены после предыдущего запуска ХП.
	IF OBJECT_ID(N'tempdb..#tData_1', N'U') IS NOT NULL 
		DROP TABLE #tData_1	
	IF OBJECT_ID(N'tempdb..#tData_2', N'U') IS NOT NULL 
		DROP TABLE #tData_2	
	IF OBJECT_ID(N'tempdb..#tData_9', N'U') IS NOT NULL 
		DROP TABLE #tData_9	

	--| Создание временной таблицы #tData_1. 
	--| Таблица предназначена для временного хранения ID терриконов текущего цеха, с датами 
	--| их последних движений из таблицы "macAlterHeapLog" на Главном сервере (из истории). 
	--| От содержимого данной таблицы зависит формирование содержимого табл. "#tData_2" (см. ниже).
	CREATE TABLE #tData_1  
	(		
	    nHeapId	       INT,
 	    dDateLastOperation DATETIME
 	)
 	
 	--| Создание временной таблицы #tData_2. 
 	--| Таблица предназначена для временного хранения ID терриконов текущего цеха и дат двух типов: 
	--| 1) из истории, и
	--| 2) актуальных на текущий момент.
	--| От количества записей в данной таблице зависит количество итераций цикла (см. ниже).
	CREATE TABLE #tData_2  
	(		
	    nHeapId	       INT,
	    dlastEdi	       DATETIME,
 	    dDateLastOperation DATETIME
 	)
 	
 	--| Создание временной таблицы #tData_9. 
 	--| Таблица предназначена для хранения текущей и расчётной (проверочной) информации о терриконах. 
 	--| В данную таблицу записывается результат выполнения ХП.
 	CREATE TABLE #tData_9  
	(		
		nHeapId		  INT,		   --| Идентификатор террикона.
		nGUID		  UNIQUEIDENTIFIER,--| GUID террикона.
		nOwnerId	  INT,		   --| Идентификатор владельца террикона.
		nUnitId		  INT,		   --| Идентификатор склада,на котором находится террикон (например, для пути "ПЦ-2/СГП-2/УФФ-1» nUnitId будет содержать Id «УФФ-1»).
		cNameHeap	  NVARCHAR(200),   --| Название террикона.
		dDateCreateHeap   DATETIME,	   --| Дата создания террикона.
		dDateEvent	  DATETIME,	   --| Дата последней операции "Зачистки" или "Замера" террикона.
		nHeapWeightBefore DECIMAL(9,3),    --| Вес террикона в таблице "macHeap".
		nHeapWeightAfter  DECIMAL(9,3),    --| Расчётный вес исходя из выполненных по террикону движений.
		nSumWeight_In	  DECIMAL(9,3),    --| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
		nSumWeight_Out	  DECIMAL(9,3),    --| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
		cValueProbeBefore NVARCHAR(MAX),   --| Хим. анализ террикона из таблицы "macHeap" (до и зменения).
		cValueProbeAfter  NVARCHAR(MAX),   --| Хим. анализ террикона рассчитанный исходя из движений (предназначен для записи в "macHeap").
		nIsAlterHeapOp    BIT,		   --| Статус изменения таблиц "macHeapOperation" и "macHeapHistory".
						   --|   nIsAlterHeapOp = 1 - у движений террикона выполнена сортировка хим. анализа 
						   --|                        в соответствии с порядком следования хим компонентов;
						   --|   nIsAlterHeapOp = 0 - сортировка хим. компонентов анализа операций не выполнялась.
		nRowAlterHeapOp   INT,		   --| Количество движений террикона у которых был отсортирован хим. анализ
						   --| в соответсвии с порядком следования хим компонентов
		dDateLastOperation   DATETIME,	   --| Дата последнего движения террикона. 		
		nIsUpdate			 BIT	   
	 )
 	
 	--| Наполнение таблицы #tData_1.
 	--| Таблица предназначена для временного хранения ID терриконов текущего цеха, 
	--| с датами их последних движений из таблицы "macAlterHeapLog" на Главном сервере. 
 	BEGIN --*
 		
 		--| Если текущая ХП выполняется на Главном сервере - запрос к табл. "macAlterHeapLog"
 		--| происходит напрямую - без использования инструкции EXEC и полного пути. 
 		IF @cDB_Name = 'MasterDB'
 		BEGIN
 			INSERT INTO #tData_1
 			SELECT nHeapId, MAX(dDateLastOperation) AS dDateLastOperation
 			FROM dbo.macAlterHeapLog
 			WHERE nFirstUnitParentId = @nLocationId
 			GROUP BY nHeapId
 		END
	 	
	 	--| Если текущая ХП выполняется на Linked-сервере (НЕ на Главном) - 
	 	--| запрос к табл. "macAlterHeapLog" осуществляется по линку, средствами EXEC.
 		IF @cDB_Name != 'MasterDB'
 		BEGIN
 			SET @SQL  = 'SELECT nHeapId, MAX(dDateLastOperation) AS dDateLastOperation '+
 				    'FROM '+(SELECT dbo.GetLinkedServer('MasterDB'))+'.dbo.macAlterHeapLog '+ 
 				    'WHERE nFirstUnitParentId = '+ CONVERT(NVARCHAR(10),@nLocationId)+' '+
 				    'GROUP BY nHeapId'
			INSERT INTO #tData_1
			EXEC (@SQL)
		END
	END --*
	
	
	--| Наполнение таблицы #tData_2.
	--| Таблица предназначена для временного хранения ID терриконов текущего цеха и дат 2-х типов: 
	--| 1) из истории, и
	--| 2) актуальных на текущий момент.
	--| От количества записей в данной таблице зависит количество итераций  цикла (см. ниже).
	--| 
	--| В таблицу попадут только те терриконы, у которых текущая дата последнего движения  
	--| отличается от даты из истории, либо если его вообще нет в таблице логов - это значит,
	--| что террикон либо новый, либо у него произошли изменения, соответственно
	--| он должен быть в списке терриконов к проверке.
	--| Данный критерий отбора необходим для сокращения времени выполнения ХП т.к. 
	--| исключает из проверки терриконы, по которым ничего не поменялось.
	--| Если нет изменений – то и пересчитывать ср. взвешенный хим. анализ нет смысла, 
	--| так же как и выполнять сортировку, ведь он и так в актуальном состоянии.

	INSERT INTO #tData_2
	SELECT  
		ms.nHeapId,
	    ISNULL(hst.dlastEdit,'19170711') AS dlastEdit,
	    ISNULL(tdd.dDateLastOperation,'19170711') AS dDateLastOperation
	FROM dbo.macHeap ms
	OUTER APPLY (
			 SELECT MAX(dlastEdit) AS dlastEdit  
			 FROM dbo.macHeapHistory msh 
			 WHERE msh.nHeapId = ms.nHeapId
		     ) hst
	OUTER APPLY (
			 SELECT nHeapId, dDateLastOperation
			 FROM #tData_1 AS td 
			 WHERE td.nHeapId = ms.nHeapId
		     ) tdd

	WHERE (ms.dDateClose IS NULL) --| Террикон не закрыт (активен).
	  AND (dbo.GetFirstUnit(ms.nUnitId) = @nLocationId) --| Местом хранения террикона является текущий цех.
	  AND (
			    (hst.dlastEdit != tdd.dDateLastOperation) --| Текущая дата последнего движения террикона 
								      --| отличается от даты из истории, либо 
			 OR (tdd.dDateLastOperation IS NULL)	      --| информации о данном терриконе вообще нет в таблице логов.
	       )
	
	--SELECT * FROM #tData_2
	
	--| Начало цикла по терриконам.
	DECLARE @nHeapId	    INT,
		@dDateLastOperation DATETIME
	DECLARE cur CURSOR LOCAL FOR SELECT nHeapId, dDateLastOperation FROM #tData_2
	 OPEN cur
		FETCH NEXT FROM cur INTO @nHeapId, @dDateLastOperation
		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			--| Сортировка хим. анализа движений террикона в соответствии 
			--| с порядком следования хим. компонентов (в случае обнаружения ошибок). 
			EXEC dbo.AlterSequenceValueProbeHeapOperation
			@nHeapId,
			@dDateLastOperation,
			@nRowCountModif OUTPUT
			
			--| Расчёт  массы и средневзвешенного хим. анализа террикона.
			EXEC dbo.GetHeapWeightAndAvgChemAnalysis
			@nHeapId,
			@nHeapWeight	 OUTPUT, --| Расчётный вес исходя из выполненных по террикону движений.
			@cHeapValueProbe OUTPUT, --| Хим. анализ террикона рассчитанный исходя из движений (предназначен для записи в "macHeap").
			@nSumWeight_In	 OUTPUT, --| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
			@nSumWeight_Out	 OUTPUT, --| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
			@dDateEvent	 OUTPUT, --| Дата последней операции "Зачистки" или "Замера" террикона.
			@dLastEditOp	 OUTPUT  --| Дата последнего движения.
			
			
			--| Запись текущей и проверочной (полученной в результате расчёта выше) информации о терриконе
			--| во временную таблицу. 
			INSERT INTO #tData_9 
			SELECT		
				ISNULL(nHeapId,0),	   --| Идентификатор террикона.
				ISNULL(nGUID,''),	   --| GUID террикона.
				ISNULL(nOwnerId,0),	   --| Идентификатор владельца террикона.
				ISNULL(nUnitId,0),	   --| Идентификатор склада,на котором находится террикон (например, для пути "ПЦ-2/СГП-2/УФФ-1» nUnitId будет содержать Id "УФФ-1").
				ISNULL(cNameHeap,''),           --| Название террикона.
				ISNULL(dDateCreate,'19170711'), --| Дата создания террикона.
				ISNULL(@dDateEvent,'19170711'), --| Дата последней операции "Зачистки" или "Замера" террикона.
				ISNULL(nWeight,0),		--| nStorWeightBefore - Вес террикона в таблице "macHeap".
				ISNULL(@nHeapWeight,0),   --| nStorWeightAfter  - Расчётный вес исходя из выполненных по террикону движений.
				ISNULL(@nSumWeight_In,0), --| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
				ISNULL(@nSumWeight_Out,0),--| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
				ISNULL( CONVERT(NVARCHAR(MAX),xValueProbe),''
					) AS cValueProbeBefore, --| Хим. анализ террикона из таблицы "macHeap" (до изменения).
				CASE 
					WHEN (LEN(@cHeapValueProbe) < 30) AND (@nHeapWeight > 0) 
					THEN ISNULL(CONVERT(NVARCHAR(MAX),xValueProbe), '') 
					ELSE @cHeapValueProbe
				END AS cValueProbeAfter,  --| Хим. анализ террикона рассчитанный исходя из движений (предназначен для записи в "macHeap").
				CASE WHEN @nRowCountModif > 0 THEN 1 ELSE 0 END AS nIsAlterHeapOp,--| Статус изменения таблиц "macHeapOperation" и "macHeapHistory".
							  --| nIsAlterHeapOp = 1 - у операций(движений) террикона выполнена сортировка хим. анализа 
							  --|                      в соответсвии с порядком следования хим компонентов;
							  --| nIsAlterHeapOp = 0 - сортировка хим. компонентов анализа операций не выполнялась.	
				ISNULL(@nRowCountModif,0) AS nRowAlterHeapOp, --| Количество движений террикона у которых был отсортирован хим. анализ
																 --| в соответсвии с порядком следования хим компонентов
				ISNULL(@dLastEditOp,'19170711'),
				NULL AS nIsUpdate --| Статус обновления (см. UPDATE'ы ниже).
			FROM dbo.macHeap WHERE nHeapId = @nHeapId
			
		--| К следующему террикону из списка.
		FETCH NEXT FROM cur INTO @nHeapId, @dDateLastOperation
		END
	CLOSE cur
	DEALLOCATE cur
	--| Конец цикла.
	
	--|	Установка статуса nIsUpdate.
	BEGIN --*
		--|	nIsUpdate = 1 - информация о весе и средневзвешенном хим. анализе террикона
		--|	должна быть обновлена в таблице "macHeap".
		--|	Выставляется при удовлетворении одного из критериев:
		--|	 - текущий вес террикона отличается от расчётного.
		--|	 - текущий ср. взвеш. хим. анализ террикона отличается от расчётного.
		--|	 - у террикона была выполнена сортировка хим. анализа движений.
		UPDATE #tData_9
		SET nIsUpdate = 1
		WHERE (nHeapWeightBefore != nHeapWeightAfter)
		   OR (cValueProbeBefore != cValueProbeAfter)
		   OR (nIsAlterHeapOp = 1)
		
		--| nIsUpdate = 0 - текущие вес и хим. анализ террикона – корректны, обновление не требуется.
		--| Отметка о таких терриконах так же должна быть внесена в таблицу логов, для того чтобы
		--| исключить их из проверки при следующем запуске ХП (см. описание при наполнение таблицы #tData_2 выше).
		UPDATE #tData_9
		SET nIsUpdate = 0
		WHERE nIsUpdate IS NULL
    END --*
    
    
    --| Передача результата на Гланый сервер.
    IF @cDB_Name = 'MasterDB'
    BEGIN
	INSERT INTO dbo.macGetHeapWeightResult
	SELECT * FROM #tData_9
    END
	IF @cDB_Name != 'MasterDB'
    BEGIN
	--| ! Участок кода ниже исправить (после приведения в порядок данных в таблице имён серверов).
	--| ! Указание константного пути к Главному серверу - временное решение .
	INSERT INTO [MasterServer].MasterDB.dbo.macGetHeapWeightResult
	SELECT * FROM #tData_9
    END
    
    
    --| Удаление временных таблиц.
    IF OBJECT_ID(N'tempdb..#tData_1', N'U') IS NOT NULL 
		DROP TABLE #tData_1
    IF OBJECT_ID(N'tempdb..#tData_2', N'U') IS NOT NULL 
		DROP TABLE #tData_2	
    IF OBJECT_ID(N'tempdb..#tData_9', N'U') IS NOT NULL 
		DROP TABLE #tData_9		
		
	
END TRY
BEGIN CATCH

	IF OBJECT_ID(N'tempdb..#tData_1', N'U') IS NOT NULL 
		DROP TABLE #tData_1	
	IF OBJECT_ID(N'tempdb..#tData_2', N'U') IS NOT NULL 
		DROP TABLE #tData_2
	IF OBJECT_ID(N'tempdb..#tData_9', N'U') IS NOT NULL 
		DROP TABLE #tData_9		
			
	DECLARE @cUserErrMessage  NVARCHAR(400) = 
				Char(10)+'Ошибка в процедуре "GetHeapWeight" (см.:' + @@servername + '\' + @cDB_Name + '). '
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
END CATCH
GO

