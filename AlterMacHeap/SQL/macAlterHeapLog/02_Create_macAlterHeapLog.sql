--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

-->*********************************************************************************************<--
--> Скрипт содержит изменения БД.
-->
--> Создание таблицы логирования изменений "macHeap"
--> хранимой процедурой "AlterMacHeap" запускаемой планировщиком в автоматическом режиме. 
-->
--> Автор: Пантелеев М.Ю.
--> Дата:  21.01.2015г.
-->*********************************************************************************************<--

DECLARE @cFileName NVARCHAR(255)

--> Имя файла скрипта! Важно - имя файла сохранятся в базе!
SET @cFileName = 'Create_macAlterHeapLog.sql'

--> Проверка, если имя файла скрипта не сохранено в таблице логирования, то выполняем скрипт. 
--> Если скрипт уже выполнялся то выводим информацию из таблицы логирования.
IF  NOT EXISTS (SELECT 1 FROM dbo.AlterDBlog WHERE cFileName = @cFileName) 
  BEGIN
	BEGIN TRY
	  PRINT @cFileName
	  BEGIN TRANSACTION
		--> Код изменения БД
				
			
		CREATE TABLE dbo.macAlterHeapLog
		(
			nLogId		     INT IDENTITY(1,1) NOT NULL --| Уникальный идентификатор записи. Первичный ключ(PK). Автоинкрементное поле. 
					     	CONSTRAINT macAlterHeapLog_nLogId_PK PRIMARY KEY,
			dDateCreateLog	     DATETIME	      NOT NULL, --| Дата добавления записи лога в таблицу.
			dLastEditLog	     DATETIME	      NULL,	--| Дата последнего изменения записи лога со статусом nIsCheck =1. 
			nIsUpdate	     BIT              NULL,	--| Статус обновления: 
									--|	nIsUpdate = 1 - информация о весе и хим. анализе террикона 
									--|	должна быть обновлена в таблице "macHeap". 
									--|	nIsUpdate = 0 - текущий вес и хим. анализ террикона – корректны, обновление не требуется. 
			nIsCheck	     BIT              NULL,	--| Статус проверки террикона: 
									--|	nIsCheck = 1 - параметры террикона в результате проверки оказались корректными, 
									--|	обновление не требуется. Записи со статусом nIsCheck = 1 необходимы для 
									--|	предотвращения повторной проверки корректных терриконов при следующем запуске ХП.
			nHeapId		     INT              NOT NULL, --| Идентификатор террикона.
			nGUID		     UNIQUEIDENTIFIER NULL,	--| GUID террикона.
			nFirstUnitParentId   INT              NULL,	--| Идентификатор подразделения, на территории которого находится террикон. 
			cOwnerName	     NVARCHAR(200)    NULL,	--| Название цеха-владельца террикона. 
			cFullNameUnit	     NVARCHAR(300)    NULL,	--| Полный путь к месту расположения террикона. 
			cNameHeap	     NVARCHAR(200)    NULL,	--| Название террикона. 
			dDateCreateHeap      DATETIME	      NULL,	--| Дата создания террикона. 
			dDateEvent	     DATETIME	      NULL,	--| Дата последней операции "Зачистки" либо "Замера" террикона. 
			nHeapWeightBefore    DECIMAL (9,3)    NULL,	--| Масса террикона из таблицы "macHeap" (масса террикона до обновления). 
			nHeapWeightAfter     DECIMAL (9,3)    NULL,	--| Масса террикона рассчитанная исходя из выполненных по нему движений. 
			nSumWeight_In	     DECIMAL (9,3)    NULL,	--| Суммарная масса пополнений террикона исходя из выполненных по нему движений. 
			nSumWeight_Out	     DECIMAL (9,3)    NULL,	--| Суммарная масса изъятий террикона исходя из выполненных по нему движений. 
			cStrValueProbeBefore NVARCHAR(MAX)    NULL,	--| Хим. анализ террикона в из таблицы "macHeap" - до обновления. 
			cStrValueProbeAfter  NVARCHAR(MAX)    NULL,	--| Хим. анализ террикона рассчитанный исходя из выполненных по нему движений. 
			cValueProbeBefore    NVARCHAR(MAX)    NULL,	--| Хим. анализ террикона в из таблицы "macHeap" - до обновления (в XML виде). 
			cValueProbeAfter     NVARCHAR(MAX)    NULL,	--| Хим. анализ террикона рассчитанный исходя из выполненных по нему движений (в XML виде). 
			nIsAlterHeapOp	     INT              NULL,	--| Статус изменения таблиц "macHeapOperation" и "macHeapHistory". 
			nRowAlterHeapOp	     INT              NULL,	--| Количество движений террикона у которых был отсортирован хим. анализ. 
			dDateLastOperation   DATETIME	      NULL	--| Дата последнего движения террикона. 
		)	
		
		--| Описание полей таблицы.
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Уникальный идентификатор записи. Первичный ключ(PK). Автоинкрементное поле. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nLogId'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата добавления записи лога в таблицу.' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'dDateCreateLog'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата последнего изменения записи лога со статусом nIsCheck =1. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'dLastEditLog'
				
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Статус обновления. nIsUpdate = 1 - информация о весе и хим. анализе террикона должна быть обновлена в таблице "macHeap". nIsUpdate = 0 - текущий вес и хим. анализ террикона – корректны, обновление не требуется. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nIsUpdate'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Статус проверки террикона. nIsCheck = 1 - параметры террикона в результате проверки оказались корректными, обновление не требуется. Записи со статусом nIsCheck = 1 необходимы для предотвращения повторной проверки корректных терриконов при следующем запуске ХП' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nIsCheck'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'GUID террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nGUID'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Идентификатор террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nHeapId'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Название цеха-владельца террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'cOwnerName'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Идентификатор подразделения, на территории которого находится террикон. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nFirstUnitParentId'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Полный путь к месту расположения террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'cFullNameUnit'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Название террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'cNameHeap'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата создания террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'dDateCreateHeap'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата последней операции "Зачистки" либо "Замера" террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'dDateEvent'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Масса террикона из таблицы "macHeap" (масса террикона до обновления). ' ,
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nHeapWeightBefore'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Масса террикона рассчитанная исходя из выполненных по нему движений. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nHeapWeightAfter'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Суммарная масса пополнений террикона исходя из выполненных по нему движений. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nSumWeight_In'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Суммарная масса изъятий террикона исходя из выполненных по нему движений. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nSumWeight_Out'
			
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Хим. анализ террикона в из таблицы "macHeap" - до обновления. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'cStrValueProbeBefore'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Хим. анализ террикона рассчитанный исходя из выполненных по нему движений. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'cStrValueProbeAfter'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Хим. анализ террикона в из таблицы "macHeap" - до обновления (в XML виде). ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'cValueProbeBefore'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Хим. анализ террикона рассчитанный исходя из выполненных по нему движений (в XML виде). ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'cValueProbeAfter'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Статус изменения таблиц "macHeapOperation" и "macHeapHistory". ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nIsAlterHeapOp'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Количество движений террикона у которых был отсортирован хим. анализ. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'nRowAlterHeapOp'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата последнего движения террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macAlterHeapLog', @level2type=N'COLUMN',
		@level2name=N'dDateLastOperation'
		
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Таблица содержит лог изменений содержимого "macHeap" хранимой процедурой "AlterMacHeap" запускаемой планировщиком в автоматическом режиме. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',
		@level1name=N'macAlterHeapLog'			
										
		--> Вызов процедуры логирования запущенных скриптов изменения БД 
		EXEC dbo.AddAlterDBlog @cFileNameIn	= @cFileName,@dDateAlterIn = NULL, @cNoteIn = ''
	
	  COMMIT TRANSACTION		
	END TRY
	BEGIN CATCH
	  
		IF XACT_STATE() <> 0
		BEGIN
			ROLLBACK TRANSACTION;
		END
		
		DECLARE @cUserErrMessage  NVARCHAR(4000)
		SET @cUserErrMessage = 'Обновление БД не возможно.' 
				
		--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
		EXEC dbo.int_Error_Return @cUserErrMessage 
		--> Процедура логирование ошибок
		EXEC dbo.Log_Error @cUserErrMessage
		--RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
	END CATCH
  END	
ELSE --> Выводим кто, когда запускал данный скрипт на этой БД
  BEGIN
    SELECT * FROM dbo.AlterDBlog WHERE cFileName = @cFileName
  END

