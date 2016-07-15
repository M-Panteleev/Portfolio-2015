--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('AddAlterHeapLog') IS NOT NULL
	DROP PROCEDURE dbo.AddAlterHeapLog
GO
-->*********************************************************************************************<--
--> Процедура логирования изменений терриконов.
--> 
--> Автор: Пантелеев М.Ю.
--> Дата:  20.01.2015г.
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.AddAlterHeapLog (
	
	@tAlterHeapLogIn   dbo.macAlterHeapLogType READONLY
)
AS
BEGIN TRY
	BEGIN TRANSACTION									
		
		--| Получение текущей даты в местном часовом поясе.
		DECLARE @dDateLog DATETIME = GETDATE() 
		
		--| Удаление из таблицы логирования записей старше месяца. 
		--| Необходимо для контроля размера таблицы логов.
 		DELETE FROM dbo.macAlterHeapLog 
		WHERE dDateCreateLog < DATEADD(MONTH, -1, @dDateLog);
		
		--| Запись лога.
		MERGE dbo.macAlterHeapLog AS dst 
		USING( 
			SELECT 
				td.nIsUpdate			      AS nIsUpdate,
				CASE WHEN td.nIsUpdate = 0 THEN 1 ELSE 0 END AS nIsCheck,
				td.nHeapId			      AS nHeapId,
				td.nGUID                              AS nGUID,
				dbo.GetFirstUnit(td.nUnitId)	      AS nFirstUnitParentId,
				su.cNameUnit			      AS cNameUnit, 
				dbo.GetFullName(td.nUnitId,0)	      AS cFullNameUnit, 
				NULLIF(td.cNameHeap,'')		      AS cNameHeap,
				NULLIF(td.dDateCreateHeap,'19170711') AS dDateCreateHeap, 
				NULLIF(td.dDateEvent,'19170711')      AS dDateEvent, 
				td.nHeapWeightBefore		      AS nHeapWeightBefore,
				td.nHeapWeightAfter		      AS nHeapWeightAfter,
				NULLIF(td.nSumWeight_In,0)	      AS nSumWeight_In, 
				NULLIF(td.nSumWeight_Out,0)	               AS nSumWeight_Out, 
				dbo.GetProbeXMLtoStr(td.cValueProbeBefore,';') AS cStrValueProbeBefore,
				dbo.GetProbeXMLtoStr(td.cValueProbeAfter, ';') AS cStrValueProbeAfter, 
				NULLIF(td.cValueProbeBefore,'')		       AS cValueProbeBefore,
				NULLIF(td.cValueProbeAfter, '')		       AS cValueProbeAfter,
				td.nIsAlterHeapOp		      AS nIsAlterHeapOp,
				td.nRowAlterHeapOp		      AS nRowAlterHeapOp,
				td.dDateLastOperation		      AS dDateLastOperation
			FROM @tAlterHeapLogIn AS td 
			LEFT JOIN dbo.stUnit AS su ON su.nUnitId = td.nOwnerId
		     ) src --| Имя источника данных (рекордсет полученный из СГП.)
				  
		  --| Перечень полей источника данных.
		  ( 
			 nIsUpdate, nIsCheck, nHeapId, nGUID, nFirstUnitParentId, cNameUnit, 
			 cFullNameUnit, cNameHeap, dDateCreateHeap, dDateEvent, nHeapWeightBefore,
			 nHeapWeightAfter, nSumWeight_In, nSumWeight_Out, cStrValueProbeBefore,
			 cStrValueProbeAfter, cValueProbeBefore, cValueProbeAfter, nIsAlterHeapOp,
			 nRowAlterHeapOp, dDateLastOperation
		   )
		ON  (src.nGUID = dst.nGUID) --| Если в таблице логов на Главном Сервере уже есть запись о терриконе;
		AND (dst.nIsCheck = 1) 	    --| и эта запись является логом проверки террикона (т.е. в результате проверки 
					    --| параметры террикона оказались корректными и по нему ничего не требуется обновлять) 
					    --| такие записи в таблице логов нужны для предотвращения повторной проверки
					    --| корректных терриконов при следующем запуске ХП, если с момента их последней проверки 
					    --| с терриконом не производилось ни каких операций;
		AND (src.nIsCheck = 1)      --| Запись о терриконе передаваемая из СГП так же имеет тип проверочной;
		AND (src.dDateLastOperation != dst.dDateLastOperation) --| Дата последней операции по террикону 
								       --| обновилась относительно лога.
															  
		--| тогда выполняется обновление записи с типом "проверочная" в таблице логов на Главном Сервере, 
		--| иначе, будет выполнена вставка новых записей лога (см. блок "NOT MATCHED")
		WHEN MATCHED THEN
			 UPDATE SET 
				  dst.dLastEditLog	   = @dDateLog,
				  dst.nIsUpdate		   = src.nIsUpdate, 
				  dst.nIsCheck		   = src.nIsCheck, 
				  dst.nHeapId		   = src.nHeapId, 
				  dst.nGUID		   = src.nGUID,
				  dst.nFirstUnitParentId   = src.nFirstUnitParentId,
				  dst.cOwnerName           = src.cNameUnit, 
				  dst.cFullNameUnit	   = src.cFullNameUnit, 
				  dst.cNameHeap		   = src.cNameHeap, 
				  dst.dDateCreateHeap      = src.dDateCreateHeap, 
				  dst.dDateEvent           = src.dDateEvent, 
				  dst.nHeapWeightBefore    = src.nHeapWeightBefore,
				  dst.nHeapWeightAfter     = src.nHeapWeightAfter, 
				  dst.nSumWeight_In	   = src.nSumWeight_In, 
				  dst.nSumWeight_Out	   = src.nSumWeight_Out, 
				  dst.cStrValueProbeBefore = src.cStrValueProbeBefore,
				  dst.cStrValueProbeAfter  = src.cStrValueProbeAfter, 
				  dst.cValueProbeBefore	   = src.cValueProbeBefore, 
				  dst.cValueProbeAfter	   = src.cValueProbeAfter, 
				  dst.nIsAlterHeapOp	   = src.nIsAlterHeapOp,
				  dst.nRowAlterHeapOp      = src.nRowAlterHeapOp, 
				  dst.dDateLastOperation   = src.dDateLastOperation

		--| Вставка новых записей в таблицу лога "macAlterHeapLog".
		WHEN NOT MATCHED 
		THEN INSERT ( 
				  dDateCreateLog,	 nIsUpdate,	       nIsCheck, 
				  nHeapId,		 nGUID,		       nFirstUnitParentId,
				  cOwnerName,		 cFullNameUnit,	       cNameHeap,
				  dDateCreateHeap,	 dDateEvent,	       nHeapWeightBefore, 
				  nHeapWeightAfter,	 nSumWeight_In,	       nSumWeight_Out,
				  cStrValueProbeBefore,	 cStrValueProbeAfter,  cValueProbeBefore,
				  cValueProbeAfter,	 nIsAlterHeapOp,       nRowAlterHeapOp,
				  dDateLastOperation
			     )
			 
		      VALUES (  
			 	  @dDateLog,		    src.nIsUpdate,	     src.nIsCheck, 
				  src.nHeapId,		    src.nGUID,		     src.nFirstUnitParentId,   
				  src.cNameUnit,            src.cFullNameUnit,	     src.cNameHeap,
				  src.dDateCreateHeap,	    src.dDateEvent,	     src.nHeapWeightBefore,
				  src.nHeapWeightAfter,     src.nSumWeight_In,	     src.nSumWeight_Out,
				  src.cStrValueProbeBefore, src.cStrValueProbeAfter, src.cValueProbeBefore,
				  src.cValueProbeAfter,	    src.nIsAlterHeapOp,	     src.nRowAlterHeapOp,
				  src.dDateLastOperation
			      )
		; --| END MERGE.
		
	COMMIT TRANSACTION	
	
END TRY
BEGIN CATCH
	  
	IF XACT_STATE() <> 0
	BEGIN
		ROLLBACK TRANSACTION;
	END	
					 	
	DECLARE @cUserErrMessage  NVARCHAR(400) = 
				Char(10)+'Ошибка в процедуре "AddAlterHeapLog".'+ Char(10);
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
END CATCH							 	
GO

