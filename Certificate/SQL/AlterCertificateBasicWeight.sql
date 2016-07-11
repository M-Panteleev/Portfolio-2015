--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('AlterCertificateBasicWeight') IS NOT NULL
	DROP PROCEDURE dbo.AlterCertificateBasicWeight
GO
-->**************************************************************************************************<--
--> Процедура выполняет получение хим. состава, расчёт базового веса и сортировку хим. анализа сертификата
--> в соответствии с порядком следования хим компонентов.
-->
-->	Автор: Пантелеев М.Ю.
-->     Ред.:		      Пантелеев М.Ю.
-->	Дата:  26.11.2014г.   14.01.2015г.
-->**************************************************************************************************<--

CREATE PROCEDURE dbo.AlterCertificateBasicWeight (
	@nCertificateIdIn INT = NULL --| ID сертификата
) 

AS
BEGIN TRY
	IF @nCertificateIdIn IS NOT NULL 
	BEGIN -- *
		DECLARE 
			@cValueProbe1 NVARCHAR(MAX) = NULL,   --| Текущий хим состав сертификата.
			@cValueProbe2 NVARCHAR(MAX) = NULL,   --| Текущий хим состав сертификата отсортированный
					  		      --| по порядку следования хим компонентов.
			@xValueProbe	    XML,
			@nMaterialId        INT,	      --| Идентификатор марки материала.							 
			@nBasicWeight1	    DECIMAL(9,3),     --| Базовый вес по сертификату.
			@nBasicWeight2	    DECIMAL(9,3),     --| Расчётный базовый вес.
			@nRegisterRWCarId   INT,	      --| Идентификатор ведомости вагона.
			@nIsShowBasicWeight BIT,	      --| Признак базового веса:
							      --|   1 - отображать;
							      --|   0 - не отображать.
			@nNetWeight	    DECIMAL(9,3) = 0, --| Корректный вес нетто сертификата(в случае обнаружения ошибки веса).
			@nIsUpdateNetWeight BIT 	      --| Признак обновления веса нетто сертификата (в случае обнаружения ошибки веса).
							      --| Значения:
							      --| 1 - необходимо обновить вес нетто сертификата содержимым @nNetWeight.
							      --| 0 – нет действий.
												  
		--| Получение данных сертификата. 					
		SELECT 
			@cValueProbe1 = CONVERT(NVARCHAR(MAX),xValueProbe), --| Текущий хим состав сертификата.
			@nMaterialId = nMaterialId,			    --| Идентификатор марки материала.
			@nBasicWeight1 = ISNULL(nBasicWeight,0), --| Базовый вес по сертификату.
			@nRegisterRWCarId = nRegisterRWCarId,    --| Идентификатор ведомости вагона.
			@nIsShowBasicWeight = nIsShowBasicWeight --| Признак базового веса.
		FROM dbo.Certificate WHERE nCertificateId = @nCertificateIdIn	
		
		--| Если отображение базового веса в сертификате требуется - тогда, 
		--| выполняются дальнейшие действия по его проверке и обновлению.
		IF @nIsShowBasicWeight = 1 
		BEGIN -- **
			
			--| ХП ниже выполняет проверку текущего хим. анализа сертификата. 
			--| Если он пуст или отсутствует - возвращает хим. анализ согласно операции отгрузки.
			EXEC dbo.GetCertificateProbe
				@nRegisterRWCarId,   --| ID ведомости вагона.
				@cValueProbe1,	     --| Текущий хим состав сертификата.
				@cValueProbe2 OUTPUT --| В данную переменную будет сохранён рез.вып. ХП 
						     --| (либо тот  хим. анализ что есть, либо хим. анализ оп. отгр.).
			
			--| Сохранение полученного хим. состава.				
			IF  (@cValueProbe1 != @cValueProbe2) 
			BEGIN
				
				BEGIN TRANSACTION
					UPDATE dbo.Certificate
					SET xValueProbe  = @cValueProbe2
					WHERE nCertificateId = @nCertificateIdIn
				COMMIT TRANSACTION
				
				SET @cValueProbe1 = @cValueProbe2
			END
			
			
			--| Получение базового веса согласно хим. анализа сертификата.
			EXEC dbo.GetCertificateBasicWeight
				@nRegisterRWCarId,	    --| ID ведомости вагона.
				@cValueProbe1,		    --| Текущий хим состав сертификата.
				@nMaterialId,		    --| Идентификатор марки материала.
				@nBasicWeight2	    OUTPUT, --| Результат нормально выполнения ХП (расчётный базовый вес).
				@nNetWeight	    OUTPUT, --| Корректный вес нетто сертификата (в случае обнаружения ошибки веса).
				@nIsUpdateNetWeight OUTPUT  --| Признак обновления веса нетто сертификата(в случае обнаружения ошибки веса).
							    --| Значения:
							    --| 1 - необходимо обновить вес нетто сертификата содержимым @nNetWeight.
							    --| 0 – нет действий.
			  
			--| Если расчётный базовый вес не соответствует базовому весу сертификата и он
			--| больше нуля - выполняется обновление параметров сертификата.
			IF  (@nBasicWeight1 != @nBasicWeight2) 
			AND (@nBasicWeight2 > 0) 
			BEGIN 
				--| Сохранение полученного базового веса.				
				BEGIN TRANSACTION
					UPDATE dbo.Certificate
					SET nBasicWeight = @nBasicWeight2
					WHERE nCertificateId = @nCertificateIdIn
				COMMIT TRANSACTION
			END  
			
			--| Если ХП GetCertificateBasicWeight вернула активный признак @nIsUpdateNetWeight 
			--| значит необходимо выполнить обновление веса нетто сертификата.
			IF  (@nIsUpdateNetWeight = 1) 
			AND (@nNetWeight > 0) 
			BEGIN 
				--| Сохранение веса нетто сертификата.				
				BEGIN TRANSACTION
					UPDATE dbo.Certificate
					SET nNetWeight = @nNetWeight
					WHERE nCertificateId = @nCertificateIdIn
				COMMIT TRANSACTION
			END  
			
		END -- **
		
		--| Сортировка хим. состава.
	
		--| ХП ниже проверяет в корректной  ли последовательности отображаются компоненты хим. состава,
		--| если нет - выполняет сортировку по nSequence.
		 EXEC dbo.AlterCertificateSequenceValueProbe 
				@nCertificateIdIn = @nCertificateIdIn,
				@nMaterialIdIn = @nMaterialId,
				@cValueProbeIn = @cValueProbe1
	 
	
	END -- *
END TRY
BEGIN CATCH
	  
	IF XACT_STATE() <> 0
	BEGIN
		ROLLBACK TRANSACTION;
	END	
	
	DECLARE @cUserErrMessage  NVARCHAR(400) = 
				Char(10)+'Ошибка в процедуре "AlterCertificateBasicWeight".'+ Char(10);
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
	
END CATCH							 	
GO

