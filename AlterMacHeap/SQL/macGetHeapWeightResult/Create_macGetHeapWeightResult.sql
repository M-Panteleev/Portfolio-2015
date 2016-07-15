--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

-->*********************************************************************************************<--
--> Скрипт содержит изменения БД.
-->
--> Создание таблицы для временного хранения информации о терриконах.
--> Таблица содержит текущую и проверочную информацию о терриконах, полученную 
--> в результате выполнения ХП "GetHeapWeight" на Главном сервере и в цехах. 
--> Содержимое данной таблицы забирает ХП "AlterMacHeap" на Главном сервере, а затем очищает.
-->
--> Автор: Пантелеев М.Ю.
--> Дата:  28.01.2015г.
-->*********************************************************************************************<--

DECLARE @cFileName NVARCHAR(255)

--> Имя файла скрипта! Важно - имя файла сохранятся в базе!
SET @cFileName = '2014.10.01_Create_macGetHeapWeightResult.sql'

--> Проверка, если имя файла скрипта не сохранено в таблице логирования, то выполняем скрипт. 
--> Если скрипт уже выполнялся то выводим информацию из таблицы логирования.
IF  NOT EXISTS (SELECT 1 FROM dbo.AlterDBlog WHERE cFileName = @cFileName) 
  BEGIN
	BEGIN TRY
	  PRINT @cFileName
	  BEGIN TRANSACTION
		--> Код изменения БД.
				
			
		CREATE TABLE macGetHeapWeightResult  
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
			dDateLastOperation  DATETIME,	   --| Дата последнего движения террикона. 		
			nIsUpdate	    BIT		   --| Статус обновления: 
							   --|	1 - информация о весе и хим. анализе террикона 
							   --|		должна быть обновлена в таблице "macHeap". 
							   --|	0 - текущий вес и хим. анализ террикона – корректны, обновление не требуется. 
		 )	
				
		--| Описание полей таблицы.
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Идентификатор террикона. ' , 
		@level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'macGetHeapWeightResult',
		@level2type=N'COLUMN', 
		@level2name=N'nHeapId'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'GUID террикона. ' ,
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nGUID'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Идентификатор цеха-владельца террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nOwnerId'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Идентификатор подразделения, на территории которого находится террикон. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nUnitId'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Название террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'cNameHeap'		
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата создания террикона. ' ,
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'dDateCreateHeap'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата последней операции "Зачистки" либо "Замера" террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'dDateEvent'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Масса террикона из таблицы "macHeap". ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nHeapWeightBefore'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Масса террикона рассчитанная исходя из выполненных по нему движений. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nHeapWeightAfter'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Суммарная масса пополнений террикона исходя из выполненных по нему движений. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nSumWeight_In'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Суммарная масса изъятий террикона исходя из выполненных по нему движений. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nSumWeight_Out'
			
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Хим. анализ террикона в из таблицы "macHeap" - до обновления (в XML виде). ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'cValueProbeBefore'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Хим. анализ террикона рассчитанный исходя из выполненных по нему движений (в XML виде). ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'cValueProbeAfter'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Статус изменения таблиц "macHeapOperation" и "macHeapHistory". ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nIsAlterHeapOp'

		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Количество движений террикона у которых был отсортирован хим. анализ. ' ,
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nRowAlterHeapOp'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Дата последнего движения террикона. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'dDateLastOperation'
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Статус обновления. nIsUpdate = 1 - информация о весе и хим. анализе террикона должна быть обновлена в таблице "macHeap". nIsUpdate = 0 - текущий вес и хим. анализ террикона – корректны, обновление не требуется. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'macGetHeapWeightResult', 
		@level2type=N'COLUMN',
		@level2name=N'nIsUpdate'
		
		
		EXEC sys.sp_addextendedproperty @name=N'MS_Description', 
		@value=N'Таблица содержит текущую и проверочную информацию о терриконах, полученную в результате выполнения ХП "GetHeapWeight". Содержимое данной таблицы забирает ХП "AlterMacHeap" на Главном сервере, а затем очищает. ' , 
		@level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',	@level1name=N'macGetHeapWeightResult'	


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

