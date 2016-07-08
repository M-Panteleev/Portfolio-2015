--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('GetEquipmentDowntime') IS NOT NULL
	DROP PROCEDURE dbo.GetEquipmentDowntime
GO
-->*********************************************************************************************<--
--> Информация о простоях оборудования
-->
--> Автор: Пантелеев М.Ю.
--> Дата:  10.11.2014.
-->*********************************************************************************************<--

CREATE PROCEDURE dbo.GetEquipmentDowntime
(
	@dDateBeginIn DATETIME = NULL,
	@dDateEndIn   DATETIME = NULL
)
AS
BEGIN TRY
	BEGIN TRANSACTION
		--| Автор: Пантелеев М.Ю.
		--| Дата: 06.11.2014 
		--| Получение информации о простоях без использования курсоров.

		SET @dDateBeginIn = ISNULL(@dDateBeginIn,CAST(0 AS DATETIME))
		SET @dDateEndIn =   ISNULL(@dDateEndIn,GETDATE())
		
		--| Удаление временных таблиц #tData1, #tData2, если по каким-либо причинам 
		--| они не были удалены после предыдущего запуска ХП.
		--| Удаление временных таблиц .
		IF OBJECT_ID(N'tempdb..#tData1', N'U') IS NOT NULL 
			DROP TABLE #tData1	
		IF OBJECT_ID(N'tempdb..#tData2', N'U') IS NOT NULL 
			DROP TABLE #tData2	
		
		--| Создание временной таблицы #tData1.
		--| Данная таблица предназначена для временного хранения выборки из таблицы "mcMeltDetail" 
		--| за интервал @dDateBeginIn  - @dDateEndIn, с данными только необходимых в дальнейшем полей.
		CREATE TABLE #tData1
		(
			nMeltDetailId INT,	--| Идентификатор записи остановки /запуска оборудования.	
			nEquipmentId  INT,	--| Идентификатор печи.
			nValueTag     INT,      --| Тип записи (остановка /запуск):
			dDateCreate   DATETIME  --| Дата остановки /запуска оборудования.
		)
		--| Наполнение таблицы #tData1 данными из таблицы "mcMeltDetail" 
		--| о запуске / остановке оборудования в период @dDateBeginIn  - @dDateEndIn.
		INSERT INTO #tData1
		SELECT 
			md.nMeltDetailId, --| Идентификатор записи остановки /запуска оборудования.	
			md.nEquipmentId,  --| Идентификатор печи.
			md.nValueTag,	  --| Тип записи (остановка /запуск):
			md.dDateCreate    --| Дата остановки /запуска оборудования.
		FROM mcMeltDetail AS md
		--| Добавил.
		LEFT OUTER JOIN
		     (
			    --| Ищем последний запуск перед датой @dDateBeginIn по каждой печи.
		            SELECT
		                   nEquipmentId,
		                   MAX(dDateCreate) AS dDateBegin
		            FROM dbo.mcMeltDetail
		            WHERE cCodeTag = 'Run' 
			     AND nValueTag=1 
			     AND dDateCreate < @dDateBeginIn
		            GROUP BY nEquipmentId
		            
		     ) lr ON lr.nEquipmentId = md.nEquipmentId
	
		WHERE dDateCreate BETWEEN ISNULL(lr.dDateBegin, @dDateBeginIn) AND @dDateEndIn
		  AND cCodeTag = 'Run'
		ORDER BY dDateCreate
		
		--| Создание временной таблицы #tData2.
		--| Данная таблица предназначена для временного хранения не сгруппированных данных о 
		--| начале и окончании простоев. 
		CREATE TABLE #tData2
		(
			nEquipmentId	   INT,	     --| Идентификатор печи.
			dIdleBegin	   DATETIME, --| Дата начала простоя.
			dIdleEnd	   DATETIME, --| Дата окончания простоя.
			nMeltDetailBeginId INT,	     --| Идентификатор записи "Остановка печи" (начало простоя).	
			nMeltDetailEndId   INT	     --| Идентификатор записи "Запуск печи" (окончание простоя).	
		)
		
		--| Наполнение таблицы #tData2 данными из таблицы #tData1 по условию.
		--| Выборка записей для вставки осуществляется по принципу:
		--| Для каждой записи Run = 0 ищется первая запись Run = 1, 
		--| у которой дата создания больше текущей Run = 0.
		--| Например:
		--| если в таблице #tData1 есть записи вида:
		--| ID1 | Run | 0 | 05.11.2014 01:00  
		--| ID2 | Run | 0 | 05.11.2014 02:00  
		--| ID3 | Run | 0 | 05.11.2014 03:00  
		--| ID4 | Run | 1 | 05.11.2014 04:00
		--| В таблицу #tData2 попадут 3 строки ID1, ID2, ID3 для каждой из которых,
		--| время окончания простоя будет ID4, в финальной выборке строки ID2, ID3 будут исключены.
		INSERT INTO #tData2
		SELECT 
			td1.nEquipmentId,	         --| Идентификатор печи.
			td1.dDateCreate   AS dIdleBegin, --| Дата начала простоя.
		    	--| Если в подзапросе «ca» не обнаружено ни одной записи, 
			--| свидетельствующей об окончании простоя, этой датой по умолчанию будет @dDateEndIn.
			ISNULL(ca.dDateCreate,@dDateEndIn) AS dIdleEnd,	--| Дата окончания простоя.
			td1.nMeltdetailId AS nMeltDetailBeginId, 	--| Идентификатор записи "Остановка печи" (начало простоя).	
			ca.nMeltdetailId  AS nMeltDetailEndId		--| Идентификатор записи "Запуск печи" (окончание простоя).	
		FROM #tData1 AS td1	
		--| Поиск первой попавшейся записи с типом Run = 1 (окончание простоя)
		--| у которой дата создания больше текущей (Run = 0) из #tData1.
		OUTER APPLY(
				 SELECT TOP(1)
					td2.nMeltdetailId,  --| Идентификатор записи "Запуск печи" (окончание простоя).	
					td2.dDateCreate     --| Дата окончания простоя.
				 FROM #tData1 AS td2	
				 WHERE 
				   --| Проверка на то, что значение td2.nValueTag 
				   --| имеет тип "Запуск печи" (окончание простоя).	
				   --| Можно было бы записать так "td2.nValueTag = 1".
				   td2.nValueTag  <> td1.nValueTag
				   --| Дата окончания простоя должна быть больше даты начала простоя.
				   AND td2.dDateCreate  > td1.dDateCreate
				   --| Записи об остановке и запуске относятся к одному и тому же оборудованию.
				   AND td2.nEquipmentId = td1.nEquipmentId
				  ORDER BY td2.dDateCreate ASC
			    ) ca
		WHERE td1.nValueTag = 0
		
		--| Финальная выборка с исключением ненужных записей.
		--| Например:
		--| если в таблицу #tData2 попали записи ID1,ID2,ID3 из выборки:
		--| ID1 | Run | 0 | 05.11.2014 01:00  
		--| ID2 | Run | 0 | 05.11.2014 02:00  
		--| ID3 | Run | 0 | 05.11.2014 03:00  
		--| ID4 | Run | 1 | 05.11.2014 04:00
		--| у каждой из которых временем окончания простоя является запись ID4, тогда,
		--| все кроме ID1 будут исключены из финальной выборки условием 
		--| MIN(t.dIdleBegin) и GROUP BY для повторяющихся значений.
		SELECT 
			t.nEquipmentId,					      --| Идентификатор печи.
			MIN(t.dIdleBegin) 	       AS dIdleBegin,	      --| Дата начала простоя.
			ISNULL(t.dIdleEnd,@dDateEndIn) AS dIdleEnd,	      --| Дата окончания простоя.
			MIN(t.nMeltDetailBeginId)      AS nMeltDetailBeginId, --| Идентификатор записи "Остановка печи" (начало простоя).
			--| Для простоев у которых датой окончания простоя является @dDateEndIn - 
			--| Id записи окончания простоя отсутствует, поэтому передаём 0.
			ISNULL(t.nMeltDetailEndId,0) AS nMeltDetailEndId,  --| Идентификатор записи "Запуск печи" (окончание простоя).	
			--| Получение Id материала.
			ISNULL((SELECT TOP 1 mm.nMaterialId FROM macMelt mm WHERE mm.nEquipmentFurnId = t.nEquipmentId AND mm.dDateMelt >= t.dIdleEnd ORDER BY mm.dDateMelt),0) AS nMaterialId
		FROM #tData2 AS t
		GROUP BY t.nEquipmentId, t.dIdleEnd,t.nMeltDetailEndId
		ORDER BY dIdleBegin	
			
		--| Удаление временных таблиц #tData1, #tData2, #tData3, #tData4.
		IF OBJECT_ID(N'tempdb..#tData1', N'U') IS NOT NULL 
			DROP TABLE #tData1	
		IF OBJECT_ID(N'tempdb..#tData2', N'U') IS NOT NULL 
			DROP TABLE #tData2	

	COMMIT TRANSACTION		
END TRY
BEGIN CATCH
	  
	IF XACT_STATE() <> 0
	BEGIN
		ROLLBACK TRANSACTION;
	END
	
	--| Удаление временных таблиц #tData1, #tData2.
	IF OBJECT_ID(N'tempdb..#tData1', N'U') IS NOT NULL 
		DROP TABLE #tData1	
	IF OBJECT_ID(N'tempdb..#tData2', N'U') IS NOT NULL 
		DROP TABLE #tData2	
	
	DECLARE @cUserErrMessage  NVARCHAR(1000) = ''
		
	SET @cUserErrMessage = 
			Char(10)+'Ошибка в процедуре "GetEquipmentDowntime".'+Char(10)
			    		
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
END CATCH
GO

