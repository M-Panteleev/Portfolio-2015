--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('GetAlterHeapLog') IS NOT NULL
	DROP PROCEDURE dbo.GetAlterHeapLog
GO
-->*********************************************************************************************<--
--> Процедура получения истории изменений терриконов.
--> 
--> Автор: Пантелеев М.Ю.
--> Ред.:		  Пантелеев М.Ю. Пантелеев М.Ю.
--> Дата:  21.01.2015г.	  16.02.2015г.	 20.02.2015
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.GetAlterHeapLog 
(
	@nHeapIdIn	INT = NULL,
	@gHeapIn	UNIQUEIDENTIFIER = NULL,
	@nUnitIdIn	INT = NULL,
	@nOwnerIdIn	INT = NULL,
	@nIsUpdate	BIT = NULL,
	@dDateBeginIn	DATETIME = NULL,
	@dDateEndIn	DATETIME = NULL
)

AS
BEGIN TRY

	--| Получение истории изменений терриконов.
	SELECT
		nLogId,		--| Уникальный идентификатор записи. Первичный ключ(PK). Автоинкрементное поле. 
		dDateCreateLog,	--| Дата добавления записи лога в таблицу.
		dLastEditLog,	--| Дата последнего изменения записи лога со статусом nIsCheck =1. 
		nIsUpdate,	--| Статус обновления: 
				--|	nIsUpdate = 1 - информация о весе и хим. анализе террикона 
				--|	должна быть обновлена в таблице "macHeap". 
				--|	nIsUpdate = 0 - текущий вес и хим. анализ террикона – корректны, обновление не требуется. 
		nIsCheck,	--| Статус проверки террикона: 
				--|	nIsCheck = 1 - параметры террикона в результате проверки оказались корректными, 
				--|	обновление не требуется. Записи со статусом nIsCheck = 1 необходимы для 
				--|	предотвращения повторной проверки корректных терриконов при следующем запуске ХП.
		nHeapId,	--| Идентификатор террикона.
		
		--| Добавил: Пантелеев М.Ю. 
		--| Дата: 20.02.2015г.
		nGUID,		      --| GUID террикона.
		
		nFirstUnitParentId,   --| Идентификатор подразделения, на территории которого находится террикон. 
		cOwnerName,	      --| Название цеха-владельца террикона. 
		cFullNameUnit,	      --| Полный путь к месту расположения террикона.
		cNameHeap,	      --| Название террикона.
		dDateCreateHeap,      --| Дата создания террикона. 
		dDateEvent,	      --| Дата последней операции "Зачистки" либо "Замера" террикона. 
		nHeapWeightBefore,    --| Масса террикона из таблицы "macHeap" (масса террикона до обновления). 
		nHeapWeightAfter,     --| Масса террикона рассчитанная исходя из выполненных движений.
		nSumWeight_In,	      --| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
		nSumWeight_Out,	      --| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
		cStrValueProbeBefore, --| Хим. анализ террикона в из таблицы "macHeap" - до обновления.
		cStrValueProbeAfter,  --| Хим. анализ террикона рассчитанный исходя из выполненных по нему движений. 
		cValueProbeBefore,    --| Хим. анализ террикона в из таблицы "macHeap" - до обновления (в XML виде). 
		cValueProbeAfter,     --| Хим. анализ террикона рассчитанный исходя из выполненных по нему движений (в XML виде). 
		nIsAlterHeapOp,       --| Статус изменения таблиц "macHeapOperation" и "macHeapHistory". 
		nRowAlterHeapOp,      --| Количество движений террикона у которых был отсортирован хим. анализ. 
		dDateLastOperation    --| Дата последнего движения террикона. 
	
	FROM dbo.macAlterHeapLog
	WHERE (
			(dDateCreateLog BETWEEN ISNULL(@dDateBeginIn, '19170711') AND ISNULL(@dDateEndIn, '26660101'))
			 --| Добавил: Пантелеев М.Ю. 
			 --| Дата: 16.02.2015г.
			 or
			(dLastEditLog BETWEEN ISNULL(@dDateBeginIn, '19170711') AND ISNULL(@dDateEndIn, '26660101'))
	       )
	  AND (nHeapId = ISNULL(@nHeapIdIn, nHeapId))
	  AND (nIsUpdate BETWEEN ISNULL(@nIsUpdate, 0) AND ISNULL(@nIsUpdate, 1)) --| Если @nIsUpdate = NULL, тогда
										  --| в выборку попадут записи обоих типов.
	
	--ORDER BY nHeapId ASC
	ORDER BY dDateCreateLog DESC, nFirstUnitParentId DESC, nHeapId ASC 
	
END TRY
BEGIN CATCH
						 	
	DECLARE @cUserErrMessage  NVARCHAR(400) = 
				Char(10)+'Ошибка в процедуре "GetAlterHeapLog".'+ Char(10);
			
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
END CATCH							 	
GO

