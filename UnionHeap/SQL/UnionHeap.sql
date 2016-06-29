--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('UnionHeap') IS NOT NULL
	DROP PROCEDURE dbo.UnionHeap
GO
-->**************************************************************************<--
--> Процедура объединения терриконов.
--> mac
--> 
--> Автор: Пантелеев М.Ю.
--> Дата:  26.05.2015г.
-->**************************************************************************<--
CREATE PROCEDURE dbo.UnionHeap
(
   	--| Входные параметры:
   	@cNameHeapIn  	 dbo.TagName = NULL, --| Название террикона(результата объединения).
	@nMaterialIdIn	 INT = NULL,		 --| ID материала террикона(результата объединения).	
	@nFractionIdIn	 INT = NULL,		 --| ID фракции террикона(результата объединения).
	@nUnitIdIn		 INT = NULL,		 --| ID площадки на которой будет находится результирующий террикон.
	@nOwnerIdIn		 INT = NULL,		 --| Цех-владелец террикона.
	@cNoteIn		 dbo.TagDescr = NULL,--| Текст примечания к террикону.
	@cHeapListIn  NVARCHAR(MAX) = '', --| Список GUID'ов объединяемых терриконов (текстом, через запятую).
	
	--| Выходные параметры:
	@nChildGUID_OUT	 UNIQUEIDENTIFIER = NULL OUTPUT --| GUID террикона образованного в результате объединения.
 )
AS
BEGIN
	BEGIN TRY
		
		DECLARE @nErrorCode INT = 0;				  --| Код ошибки.
		DECLARE @cMes		NVARCHAR(MAX) = '';		  --| Текст ошибки.
		DECLARE @cEnter		NVARCHAR(1)	  = CHAR(10); --| Символ перевода строки.
		DECLARE @cDBName	NVARCHAR(10)  = DB_NAME();--| Название текущей БД. 
		DECLARE @nIsLink	INT = 0;			      --| Статус, отвечает за место выполнения ХП:
												      --|		@nIsLink = 1 - по линку на Главном Сервере;
												      --|		@nIsLink = 0 – в текущей БД.
		
		--| Проверка входных параметров на NULL.
		IF (@cNameHeapIn 	IS NULL) SET @cMes += N' - Не задано наименование террикона.' + @cEnter
		IF (@nMaterialIdIn	IS NULL) SET @cMes += N' - Не указан материал террикона.' + @cEnter
		IF (@nFractionIdIn	IS NULL) SET @cMes += N' - Не указана фракция террикона.' + @cEnter
		IF (@nUnitIdIn		IS NULL) SET @cMes += N' - Не указанно место хранения террикона.' + @cEnter
		IF (@nOwnerIdIn		IS NULL) SET @cMes += N' - Не указан цех-владелец.' + @cEnter
		IF (@cHeapListIn = '')		 SET @cMes += N' - Не указаны терриконы для объединения.' + @cEnter
		
		IF (@cMes != '') RAISERROR ('Ошибка объединения терриконов.',16,1)
		
		
		--| Удаление временной таблицы #tGUIDsTable_1, если по каким-либо причинам 
		--| она не была удалена после предыдущего запуска ХП.
		--| Удаление временной таблицы #tGUIDsTable_1.
		IF OBJECT_ID(N'tempdb..#tGUIDsTable_1', N'U') IS NOT NULL 
			DROP TABLE #tGUIDsTable_1
		
		--| Создание временной таблицы #tGUIDsTable_1.
		--| Таблица предназначена для временного хранения GUID’ов объединяемых терриконов.
		CREATE TABLE #tGUIDsTable_1
		(
			nGUID UNIQUEIDENTIFIER
		)
		
		--| Наполнение временной таблицы #tGUIDsTable_1.
		--| Получение GUID'ов путём преобразования входной строки в таблицу по разделителю "," 
		--| с сохранением полученного результата в таблицу #tGUIDsTable_1.
		DECLARE @SQL NVARCHAR(MAX)
		SET @SQL = @cHeapListIn
		SET @SQL = 'SELECT '''+REPLACE(LTRIM(@SQL), ',', ''' AS nGUID UNION ALL SELECT ''')+''''
		INSERT INTO #tGUIDsTable_1
		EXEC(@SQL);
		
		--| Генерация исключения с выводом сообщения об ошибке если:
		--| 1) нет терриконов для объединения;
		--| 2) передан только один террикон. 
		IF NOT EXISTS (SELECT nGUID FROM #tGUIDsTable_1) SET @cMes += N' - Не указаны терриконы для объединения.' + @cEnter			
		IF (SELECT COUNT(nGUID) FROM #tGUIDsTable_1) = 1 SET @cMes += N' - Для объединения необходимо более одного террикона.' + @cEnter			
		IF (@cMes != '') RAISERROR ('Ошибка объединения терриконов.',16,1)
		
		--| Определяем где выполнять объединение терриконов - в текущей БД или по линку.
		--| Если корневым подразделением места-хранения не является ID подразделения-владельца,
		--| значит, местом хранения террикона будет площадка на Главном Сервере.
		--| соответственно, создание террикона должно происходить по линку.
		IF ( dbo.GetFirstUnit(@nUnitIdIn) != @nOwnerIdIn )
		AND( @cDBName != 'Core_db') --| и текущая БД не есть Core_db (обработка ошибки линка на самого себя) 
			SET @nIsLink = 1
		
		--| Если местом хранения террикона (в результате объединения)
		--| НЕ будет текущий цех - создаём его по линку.
		IF (@nIsLink = 1)
		BEGIN
			--| SQL запрос для выполнения на linked-сервере.
			DECLARE @SQLQuery NVARCHAR(MAX) = (SELECT dbo.GetNameLinkedServer('Core_db'))+'.dbo.UnionHeap';
			
			--| Здесь будет GUID террикона образованного в результате объединения.			
			DECLARE @nChildGUID  UNIQUEIDENTIFIER = NULL;
			
			--| Выполнение SQL запроса на linked-сервере с передачей параметров.
			EXEC @SQLQuery 
					--| Передача входных параметров:
					@cNameHeapIn, 	 --| Название террикона.
					@nMaterialIdIn,	 --| ID материала террикона.	
					@nFractionIdIn,	 --| ID фракции террикона.
					@nUnitIdIn,		 --| ID площадки на которой будет находится результирующий террикон.
					@nOwnerIdIn,	 --| Цех-владелец террикона.
					@cNoteIn,		 --| Текст примечания к террикону.
					@cHeapListIn, 	 --| Список GUID'ов объединяемых терриконов (текстом, через запятую).
									 --| Получение результата.
					@nChildGUID OUTPUT --| GUID террикона образованного в результате объединения.
			
			--| Если объединение терриконов на linked-сервере прошло корректно–результирующий террикон был создан, 
			--| тогда, закрываем терриконы выбранные для объединения.
			--| (результирующий террикон придёт после синхронизации).
			IF (@nChildGUID IS NOT NULL)
			BEGIN
				UPDATE dbo.macHeap SET
					nChildGUID = @nChildGUID,
					dDateClose = GETDATE()
				WHERE nGUID IN (SELECT nGUID FROM #tGUIDsTable_1)
			END
		END 
		ELSE --| Если местом хранения террикона будет текущий цех.
		BEGIN
			BEGIN TRANSACTION
			
			--| Создаём террикон(результата объединения) в текущей БД.
			EXEC dbo.AddHeap
				@nUnitIdIn		= @nUnitIdIn,	
				@nOwnerIdIn		= @nOwnerIdIn,
				@cNameHeapIn	= @cNameHeapIn,
				@nMaterialIdIn	= @nMaterialIdIn,
				@nFractionIdIn	= @nFractionIdIn,	
				@cNoteIn		= @cNoteIn,
				@nIsUnionIn		= 1		

			DECLARE @nHeapGUID 	  UNIQUEIDENTIFIER = NULL; --| GUID террикона.
			DECLARE @nHeapId   	  INT			   = NULL; --| ID террикона.
			DECLARE @nMaterialId  INT			   = NULL; --| ID материала террикона.
			
			--| Получение параметров только-что созданного террикона.
			SELECT 
				@nHeapGUID 	  = nGUID,
				@nHeapId	  = nHeapId,
				@nMaterialId  = nMaterialId
			FROM dbo.macHeap
			WHERE(cNameHeap	   = @cNameHeapIn)
			 AND (nUnitId	   = @nUnitIdIn)
			 AND (nOwnerId	   = @nOwnerIdIn) 
			 AND (nMaterialId  = @nMaterialIdIn) 
			 AND (nFractionId  = @nFractionIdIn)
			 AND (nIsUnion	   = 1)
			 AND (dDateCreate  > DATEADD(MINUTE,-5,GETDATE()) )
			
			--| Если террикон не был найден(создан) - генерируется исключение.
			IF (@nHeapGUID IS NULL)
			BEGIN
				SET @nErrorCode = 1;
				RAISERROR ('Ошибка объединения терриконов.',16,1)
			END
			
			--| Исходные терриконы закрываются только в цехах (пользователь должен сразу увидеть, что они закрылись).
			--| После прохождения синхронизации закрытые терриконы спокойно обновятся на Главном Сервере. 
			IF (@cDBName != 'Core_db')
			UPDATE dbo.macHeap SET
				nChildGUID = @nHeapGUID, --| Ссылка на дочерний террикон, образованный в результате слияния.
				dDateClose = GETDATE()		--| Дата закрытия террикона.
			WHERE nGUID IN (SELECT nGUID FROM #tGUIDsTable_1)
			
			DECLARE @nHeapWeight		DECIMAL(9,3);  --| Здесь будет масса террикона - результата объединения.
			DECLARE @cHeapValueProbe NVARCHAR(MAX); --| Здесь будет хим. анализ террикона - результата объединения.
			
			--| Расчёт веса и средневзвешенного хим. анализа террикона в результате объединения.
			EXEC dbo.GetWeightAndChemAnalysisHeapUnion 
				--| Передача входных параметров:
				@cHeapListIn,				--| Список GUID'ов терриконов выбранных для объединения.
				@nMaterialId,				--| ID материала террикона-результата объединения.
				--| Получение результата.
				@nHeapWeight	 OUTPUT, --| Расчётный вес террикона в результате объединения.
				@cHeapValueProbe OUTPUT  --| Хим. анализ террикона в результате объединения.
			
			--| Конвертирование хим. анализа террикона из строки в XML.
			DECLARE @xHeapValueProbe XML;
			SET @xHeapValueProbe = CONVERT (XML,@cHeapValueProbe);
			
			--| Обновление массы и хим. анализа террикона(результата объединения) в macHeap.
			UPDATE dbo.macHeap SET
				nWeight		= @nHeapWeight,	   --| Масса террикона в результате объединения.
				xValueProbe = @xHeapValueProbe --| Хим. анализ террикона в результате объединения.
			WHERE nGUID = @nHeapGUID
				
			--| Добавляем операцию пополнения хранилища.
			INSERT INTO dbo.macHeapOperation
				   (nHeapId, nWeight, xValueProbe, nWeightFactor, nIsExecuted, dDateOperation)
			VALUES (@nHeapId, @nHeapWeight, @xHeapValueProbe, 1, 1, GETDATE())
			
			--| Получение ID только-что созданной операции(необходимо для записи истории, см. ниже).
			DECLARE @nHeapOperationId INT = (SELECT nHeapOperationId 
												FROM dbo.macHeapOperation
												WHERE (nHeapId = @nHeapId)
												  AND (nWeight = @nHeapWeight)
												  AND (dDateOperation  > DATEADD(MINUTE,-5,GETDATE())) )
			
			--| Если операция не была найдена(создана) - генерируется исключение.
			IF (@nHeapOperationId IS NULL)
			BEGIN
				SET @nErrorCode = 2;
				RAISERROR ('Ошибка объединения терриконов.',16,1)
			END
			
			--| Запись истории пополнения хранилища.
			INSERT INTO dbo.macHeapHistory
				   (nHeapOperationId, nHeapId, nWeight, xValueProbe, cNote)
			VALUES (@nHeapOperationId, @nHeapId, @nHeapWeight, @xHeapValueProbe, 'Объединение терриконов' )
			
			--| Указываем в качестве выходного параметра GUID террикона образованного в результате объединения.
			--| Данный параметр опрашивается, в ситуации, когда текущая ХП выполняется по линку.
			--| Если выходной параметр NOT NULL значит инициатор вызова получает подтверждение того, 
			--| что всё прошло корректно и можно закрывать исходные терриконы (см. блок "IF(@nIsLink = 1)" в начале ХП.
			SET @nChildGUID_OUT = @nHeapGUID	
			
			--| Удаление временной таблицы #tGUIDsTable_1.
			IF OBJECT_ID(N'tempdb..#tGUIDsTable_1', N'U') IS NOT NULL 
				DROP TABLE #tGUIDsTable_1
			
			COMMIT TRANSACTION
		END
	END TRY
	BEGIN CATCH
		IF XACT_STATE() <> 0
		BEGIN
			ROLLBACK TRANSACTION;
		END	
		--| Удаление временной таблицы #tGUIDsTable_1.
		IF OBJECT_ID(N'tempdb..#tGUIDsTable_1', N'U') IS NOT NULL 
			DROP TABLE #tGUIDsTable_1
		
		
		SET @cMes = N'В процессе объединения терриконов возникли ошибки:' + @cEnter + @cMes;
					
		IF (@nErrorCode = 1) 
			SET @cMes += N' - Террикон результат-объединения не найден.' + @cEnter
			
		IF (@nErrorCode = 2) 
			SET @cMes += N' - Не найден идентификатор операции движения.' + @cEnter
		
		IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.stUnit WHERE nUnitId = @nUnitIdIn)
			SET @cMes += N' - Не найдено подразделение-склад.'+ @cEnter
		
		IF @nOwnerIdIn IS NOT NULL AND NOT EXISTS(SELECT TOP 1 1 FROM dbo.stUnit WHERE nUnitId = @nOwnerIdIn)
			SET @cMes += N' - Неверно указано подразделение-владелец.'+ @cEnter
		
		--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
		EXEC dbo.int_Error_Return @cMes 
		--> Процедура логирование ошибок
		EXEC dbo.Log_Error @cMes
		RETURN (50000 + ISNULL(ERROR_NUMBER(),0))	
	END CATCH

END
GO
