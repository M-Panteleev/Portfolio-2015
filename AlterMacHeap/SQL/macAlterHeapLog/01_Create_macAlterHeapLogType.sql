--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

-->*********************************************************************************************<--
--> Скрипт содержит изменения БД.
-->
--> Создание табличного типа данных.
--> Данный тип предназначен для передачи входной информации табличного типа в
--> хранимую процедуру "AddAlterHeapLog".
--> Процедура, в свою очередь, осуществляет запись лога изменений террикона в таблицу "macAlterHeapLog". 
--> 
--> Автор: Пантелеев М.Ю.
--> Дата:  20.01.2015г.
-->*********************************************************************************************<--


DECLARE @cFileName NVARCHAR(255)

--> Имя файла скрипта! Важно - имя файла сохранятся в базе!
SET @cFileName = 'Create_macAlterHeapLogType.sql'

--> Проверка, если имя файла скрипта не сохранено в таблице логирования, то выполняем скрипт. 
--> Если скрипт уже выполнялся то выводим информацию из таблицы логирования.
IF  NOT EXISTS (SELECT 1 FROM dbo.AlterDBlog WHERE cFileName = @cFileName) 
  BEGIN
	BEGIN TRY
	  BEGIN TRANSACTION
		--> Код изменения БД

		IF EXISTS (SELECT 1 FROM sys.systypes 
			   WHERE name = N'macAlterHeapLogType')
		DROP TYPE dbo.macAlterHeapLogType
	
			
		CREATE TYPE dbo.macAlterHeapLogType AS TABLE
		(
			nHeapId		  INT		   NULL, --| Идентификатор террикона.
			nGUID		  UNIQUEIDENTIFIER NULL, --| GUID террикона.
			nOwnerId	  INT		   NULL, --| Идентификатор владельца террикона.
			nUnitId		  INT		   NULL, --| Идентификатор склада,на котором находится террикон (например, для пути "ПЦ-2/СГП-2/УФФ-1" nUnitId будет содержать Id "УФФ-1").
			cNameHeap	  NVARCHAR(200)    NULL, --| Название террикона.
			dDateCreateHeap   DATETIME	   NULL, --| Дата создания террикона.
			dDateEvent	  DATETIME	   NULL, --| Дата последней операции "Зачистки" или "Замера" террикона.
			nHeapWeightBefore DECIMAL(9,3)     NULL, --| Вес террикона в таблице "macHeap".
			nHeapWeightAfter  DECIMAL(9,3)     NULL, --| Расчётный вес исходя из выполненных по террикону движений.
			nSumWeight_In	  DECIMAL(9,3)     NULL, --| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
			nSumWeight_Out	  DECIMAL(9,3)     NULL, --| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
			cValueProbeBefore NVARCHAR(MAX)    NULL, --| Хим. анализ террикона из таблицы "macHeap".
			cValueProbeAfter  NVARCHAR(MAX)    NULL, --| Хим. анализ террикона рассчитанный исходя из движений (предназначен для записи в таблицу "macHeap").
			nIsAlterHeapOp    BIT,			 --| Статус изменения таблиц "macHeapOperation" и "macHeapHistory":
								 --|   nIsAlterHeapOp = 1 - у операций(движений) террикона выполнена сортировка хим. анализа 
								 --|                        в соответсвии с порядком следования хим компонентов;
								 --|   nIsAlterHeapOp = 0 - сортировка хим. компонентов анализа операций не выполнялась.
			nRowAlterHeapOp    INT		   NULL, --| Количество движений террикона у которых был отсортирован хим. анализ.
			dDateLastOperation DATETIME	   NULL, --| Дата последнего движения (операции) террикона. 
			nIsUpdate	   BIT	 		 --| Статус обновления:
								 --|	 nIsUpdate = 1 - информация о весе и хим. анализе террикона должна быть обновлена в таблице "macHeap".
								 --|	 nIsUpdate = 0 - текущий вес и хим. анализ террикона – корректны, обновление не требуется. 
		)
		
		GRANT EXECUTE ON TYPE::dbo.macAlterHeapLogType TO [Role_UserDefault]	
    								
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
		
	END CATCH
  END	
ELSE --> Выводим кто, когда запускал данный скрипт на этой БД
  BEGIN
    SELECT * FROM dbo.AlterDBlog WHERE cFileName = @cFileName
  END

