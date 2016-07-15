--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('AlterMacHeap') IS NOT NULL
	DROP PROCEDURE dbo.AlterMacHeap
GO
-->*********************************************************************************************<--
--> Процедура обновляет значения "nWeight" и "xValueProbe" таблицы "dbo.macHeap"
--> для терриконов, хим. анализ или масса которых отличаются от расчётных.
--> Запуск процедуры выполняется скриптом "syncHeap.js" перед раздачей 
--> информации о терриконах на СГП.
--> 
--> Автор: Пантелеев М.Ю.
--> Дата:  12.12.2014г.
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.AlterMacHeap 

AS
BEGIN TRY
	
	--| Очищение промежуточной таблицы, временно хранящей рекордсет с Linked-серверов.  
	IF (SELECT COUNT(nHeapId) FROM dbo.macGetHeapWeightResult) > 0
	TRUNCATE TABLE dbo.macGetHeapWeightResult
	
	
	DECLARE @cLinkedServerName    NVARCHAR(300),  --| Название Linked-сервера.
		@cLinkedDataBaseName  NVARCHAR(300),  --| Название БД Linked сервера.
		@SQL		      NVARCHAR(MAX)   --| Переменная для хранения SQL запроса, 
						      --| выполняемого инструкцией EXEC.
	
	--| Цикл по Linked-серверам.
	--| Предназначен для сбора текущих и расчётных данных о терриконах.
	DECLARE Server_CUR CURSOR LOCAL FOR SELECT NULL AS cLinkedServerName,  --| Это Главный Сервер, для него нет Linked-сервера на самого себя.
						   NULL AS cLinkedDataBaseName --| Это Главный Сервер, для него нет необходимости в указании БД.
					    UNION
					    SELECT QUOTENAME(ls.cNameServer) AS cLinkedServerName,  --| Название Linked-сервера.
					    	   ls.cDataBase		     AS cLinkedDataBaseName --| Название БД Linked сервера.
					    FROM dbo.configLinkedServer ls 
					    WHERE ls.cCodeLinked IN ('Plant1','Plant2','Plant4','Plant6')
					    ORDER BY cLinkedDataBaseName
	OPEN Server_CUR
	
		FETCH NEXT FROM Server_CUR INTO @cLinkedServerName, @cLinkedDataBaseName
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @SQL = CASE 
					--| Если это НЕ Главный Сервер – при вызове ХП "GetHeapWeight" 
					--| должны указываться имя Linked-сервера и название БД.
					WHEN (@cLinkedServerName   IS NOT NULL) 
					 AND (@cLinkedDataBaseName IS NOT NULL) 
					THEN  @cLinkedServerName + '.' + @cLinkedDataBaseName + '.'
				  	--| Для вызова ХП на Ядре название сервера и БД не требуются.
				        ELSE ''
	   			   END + 'dbo.GetHeapWeight'

			--| Вызов ХП "GetHeapWeight" на Linked-сервере (и самом Ядре).
			EXEC (@SQL)
			
			--| В результате положительного выполнения ХП "GetHeapWeight" на Linked-сервере (и Ядре)
			--| результирующий набор данных по линку передаётся обратно на Главный Сервер и 
			--| записывается в таблицу "macGetHeapWeightResult".
			--| Таблица предназначена для временного хранения информации о терриконах, полученной из цехов.
			--| Затем, после UPDATE’а таблицы "macHeap" и записи лога изменений,
			--| таблица "macGetHeapWeightResult" очищается командой "TRUNCATE" (см. ниже).
		
		--| К следующему серверу из списка.
		FETCH NEXT FROM Server_CUR INTO @cLinkedServerName, @cLinkedDataBaseName
		END
		
	CLOSE Server_CUR
	DEALLOCATE Server_CUR
	--| Конец цикла.
	
	
	IF EXISTS (SELECT TOP(1) 1 FROM dbo.macGetHeapWeightResult)
	BEGIN
		--| Обновление массы и хим. анализа терриконов имеющих статус nIsUpdate = 1.
		BEGIN TRANSACTION
		UPDATE dbo.macHeap SET
			nWeight		= td.nHeapWeightAfter,
			xValueProbe = CONVERT(XML,td.cValueProbeAfter)
		FROM dbo.macHeap AS ms, 
			 macGetHeapWeightResult AS td
		WHERE ms.nGUID = td.nGUID
		  AND td.nIsUpdate = 1
		COMMIT TRANSACTION	
		
		
		--| Логирование изменений терриконов.
		BEGIN
			--| Создание входной табличной переменной для передачи данных в ХП "AddAlterHeapLog" (см. ниже).
			DECLARE @tAlterHeapLogIn_tmp	 dbo.macAlterHeapLogType
			
			--| Наполнение данными. 
			INSERT INTO @tAlterHeapLogIn_tmp
			SELECT  * FROM dbo.macGetHeapWeightResult AS td	
			
			--| Запись лога.
			EXEC dbo.AddAlterHeapLog @tAlterHeapLogIn = @tAlterHeapLogIn_tmp
		END
	END
		
	--| Очищение промежуточной таблицы, временно хранящей рекордсет с Linked-серверов.  
	IF (SELECT COUNT(nHeapId) FROM dbo.macGetHeapWeightResult) > 0
	TRUNCATE TABLE dbo.macGetHeapWeightResult
			
END TRY
BEGIN CATCH
	  
	IF XACT_STATE() <> 0
	BEGIN
		ROLLBACK TRANSACTION;
	END	
	
	--| Очищение промежуточной таблицы, временно хранящей рекордсет с Linked-серверов.  
	IF (SELECT COUNT(nHeapId) FROM dbo.macGetHeapWeightResult) > 0
	TRUNCATE TABLE dbo.macGetHeapWeightResult
			 	
	DECLARE @cUserErrMessage NVARCHAR(400)
	SET @cUserErrMessage = Char(10) + 'Ошибка в процедуре "AlterMacHeap". ' + 
						   Char(10) + '(см.:' + @@servername + '\' + DB_NAME() + '). '
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
END CATCH							 	
GO

