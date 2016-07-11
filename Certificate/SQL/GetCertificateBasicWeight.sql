--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('GetCertificateBasicWeight') IS NOT NULL
	DROP PROCEDURE dbo.GetCertificateBasicWeight
GO
-->*********************************************************************************************<--
--> Процедура рассчитывает базовый вес сертификата для одной из 2-х ситуаций:
-->	1)согласно хим. анализа сертификата,
-->	2)согласно хим. анализа операции отгрузки.
--> 
--> Автор: Пантелеев М.Ю.
--> Ред:		  Пантелеев М.Ю.
--> Дата:  25.11.2014	  14.01.2015
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.GetCertificateBasicWeight
	(
		  @nRegisterRWCarIdIn	 INT = NULL,
		  @cValueProbeIn	 NVARCHAR(MAX) = NULL,
		  @nMaterialIdIn	 INT = NULL,
		  @nBasicWeightOut	 DECIMAL(9,3) = 0 OUTPUT, --| Выходной параметр. Базовый вес сертификата.
		  @nNetWeightOut         DECIMAL(9,3) = 0 OUTPUT, --| Выходной параметр. Вес нетто сертификата.
		  @nIsUpdateNetWeightOUT BIT = 0          OUTPUT  --| Выходной параметр. Статус обновления веса нетто сертификата.
		 
		  --| Значения @nIsUpdateNetWeightOUT:
		  --| 1 - вызывающему коду необходимо обновить вес нетто сертификата содержимым @nNetWeightOut.
		  --| 0 – нет действий.
	 )
AS
BEGIN TRY
	
	--| Если хотябы один из входных параметров передан -
	--| определяется ID операции отгрузки.
	IF (@nRegisterRWCarIdIn IS NOT NULL) 
	BEGIN   
		DECLARE @nBasicWeight DECIMAL(9,3) = 0,
			@nOperationId INT = NULL
		
		--| Получение id операции отгрузки.
		SELECT 
			@nOperationId = op.nOperationId
		FROM dbo.Operations op
		INNER JOIN dbo.RegisterRWCar rr ON rr.nRegisterRWCarId = op.nRegisterRWCarId AND op.nTypeOperationId = -4
		LEFT JOIN dbo.dctMaterial mt ON mt.nMaterialId = rr.nMaterialId
		WHERE op.nRegisterRWCarId = @nRegisterRWCarIdIn
	END
	
	--| 1) Базовый вес согласно хим. анализа сертификата.
	--| Если во входном параметре был передан хим. анализ, значит
	--| базовый вес будет рассчитан согласно хим. анализа сертификата.
	IF  (@cValueProbeIn	 IS NOT NULL)
	AND (@nRegisterRWCarIdIn IS NOT NULL) 
	BEGIN --*
		DECLARE
			@xValueProbe  XML = NULL,
			@nMaterialId  INT = NULL,
			@nWeight      dbo.Weight = 0,
			@nNetWeightCE dbo.Weight = 0, --| Вес нетто сертификата.
			@nNetWeightRW dbo.Weight = 0, --| Вес нетто вагона, согласно взвешивания на ЖД весовой.
			@nNetWeightOP dbo.Weight = 0  --| Вес нетто вагона, согласно операции отгрузки.
			
		
		SELECT
			@xValueProbe  = CONVERT(XML,@cValueProbeIn),
			--| Получение id материала согласно операции отгрузки.
			@nMaterialId  = ISNULL(@nMaterialIdIn, (SELECT t.nMaterialId 
								FROM dbo.Operations t 
								WHERE t.nOperationId = @nOperationId)),
			--| Получение нетто сертификата.
			@nNetWeightCE = ISNULL( (SELECT TOP(1) nNetWeight 
					         FROM dbo.Certificate 
					         WHERE nRegisterRWCarId = @nRegisterRWCarIdIn)
					      ,0 ),
			
			--| Получение нетто согласно взвешивания на весовой.
			@nNetWeightRW = ISNULL( (SELECT (ISNULL(nGrossWeight,0) - ISNULL(nTareWeight,0)) 
						 FROM dbo.RegisterWeighting 
						 WHERE nWeightingId = (SELECT nWeightingId 
								       FROM dbo.RegisterRWCar 
								       WHERE nRegisterRWCarId = @nRegisterRWCarIdIn))
					      ,0 )
		
		--| Если вес нетто сертификата соответствует весу нетто весовой, значит 
		--| для сертификата была выполнена операция «Обновить вес нетто», соответственно 
		--| базовый вес должен рассчитываться исходя из веса нетто по провеске и
		--| хим. анализа сертификата (который мог редактироваться пользователем). 
		
		--| Если вес нетто сертификата НЕ соответствует весу нетто весовой, значит
		--| должен быть получен вес нетто операции отгрузки.
		IF  (@nNetWeightRW <= 0) --| Отрицательное нетто говорит о том, что вагон не взвешивался на брутто.
		 OR (@nNetWeightCE != @nNetWeightRW) --| Вес нетто сертификата НЕ соответствует весу нетто весовой.
		BEGIN --**	
			--| Получение веса нетто согласно операции отгрузки.
			SET @nNetWeightOP = 
			ISNULL(
				(
				SELECT	
					po.nShippingWeight
				FROM dbo.Operations op
				LEFT JOIN (	SELECT nOperationId,
						       SUM(po.nNetWeight) AS nShippingWeight
						FROM
						(
							SELECT
								op.nTypeOperationId,
								ISNULL(op.nParentOperationId, op.nOperationId)			    AS nOperationId,
								CASE WHEN po.nInputParameter = 0 THEN -1 ELSE 1 END * rb.nNetWeight AS nNetWeight
							FROM dbo.Operations op 
							INNER JOIN dbo.ParameterOperations po ON op.nOperationId = po.nOperationId
							INNER JOIN dbo.RegisterBoxes rb ON rb.nRegisterBoxId = po.nRegisterBoxId
							WHERE op.nTypeOperationId IN (-4)
							UNION ALL
								SELECT -4,
									bw.nOperationLoadingId,
									bw.nWeight
								FROM dbo.BigBagsWeighting bw
						) po
						GROUP BY po.nOperationId	) 
						po ON po.nOperationId = op.nOperationId
				WHERE op.nTypeOperationId = -4	
				AND   op.nOperationId = @nOperationId
				),0)
		END --**
		
		--| Если вес нетто сертификата равен весу нетто вагона по провеске, тогда
		--| базовый вес будет рассчитываться исходя из веса нетто ЖД весовой.
		IF  (@nNetWeightRW > 0)
		AND (@nNetWeightCE = @nNetWeightRW) 
			SET @nWeight = @nNetWeightRW
		
		--| Если вес нетто сертификата равен весу нетто операции отгрузки, либо имеет
		--| отрицатьльное значение (показатель того, что на момент создания сертификата
		--| вагон не взвешивался на ЖД весовой: брутто – тара = число с минусом) тогда
		--| базовый вес будет рассчитываться исходя из веса нетто операции отгрузки.	
		IF  ( (@nNetWeightOP > 0) AND (@nNetWeightCE = @nNetWeightOP) ) OR
		    ( (@nNetWeightOP > 0) AND (@nNetWeightCE < 0) ) 
			SET @nWeight = @nNetWeightOP
		
		--| Если сертификат имеет нулевой вес, либо
		--| актуальны три критерия : 
		--|	  1) вес нетто сертификата НЕ равен весу нетто ЖД весовой;
		--|	  2) вес нетто сертификата НЕ равен весу нетто операции отгрузки;
		--|	  3) вес нетто сертификата НЕ является отрицательным числом (показатель того, что
		--|		 на момент создания сертификата вагон не взвешивался на ЖД весовой: брутто – тара = число с минусом)
		--| значит у сертификата проблемы с весом (ошибка), в таком случае 
		--| базовый вес будет рассчитываться исходя из одного из двух весов (в приоритете ЖД весовая).			
		IF (@nNetWeightCE = 0) OR
		   (
		     (@nNetWeightCE != @nNetWeightRW) AND
		     (@nNetWeightCE != @nNetWeightOP) AND
		     (@nNetWeightCE > 0 )
			)
		BEGIN
			IF @nNetWeightRW <= 0 SET @nNetWeightRW = NULL
			IF @nNetWeightOP <= 0 SET @nNetWeightOP = NULL
			
			SET @nWeight = COALESCE(@nNetWeightRW,@nNetWeightOP,0)
			SET @nNetWeightOut = @nWeight
			SET @nIsUpdateNetWeightOut = 1 --| Обнаружена ошибка веса, вызывающий код, согласно этого статуса
						       --| должен обновить вес нетто сертификата содержимым @nNetWeightOut.
		END
		
		IF @nWeight > 0
		BEGIN --***
			--| Расчёт базового веса. 
			SELECT
				@nBasicWeight = SUM(CAST(t.cValueParametr AS FLOAT)) * @nWeight / ISNULL(MAX(mtt.nConversionWeight), 1)
			FROM (SELECT 
				t.c.query('./nParametrId').value('.','INT') AS nParametrId,
				CONVERT(FLOAT,t.c.query('./cValueParametr').value('.','FLOAT')) AS cValueParametr
			      FROM @xValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
			      ) t
			INNER JOIN dbo.dctMatParamLink mpl ON mpl.nParametrId = t.nParametrId
			INNER JOIN dbo.dctMatType mtt ON mtt.nMaterialTypeId = mpl.nMaterialTypeId
			WHERE mpl.nIsBasic = 1
				  AND mtt.nMaterialTypeId = (SELECT t.nMaterialTypeId 
							     FROM dbo.dctMaterial t 
							     WHERE t.nMaterialId = dbo.GetFirstMatParent(@nMaterialId))
		END --***
	END --*
	
	--| 2) Базовый вес согласно операции отгрузки.
	--| Если во входном параметре был передан id ведомости вагона (и при этом, не было входного хим. анализа), 
	--| значит базовый вес будет рассчитан согласно хим. анализа операции отгрузки. 
	IF   (@nRegisterRWCarIdIn IS NOT NULL) 
	 AND (@cValueProbeIn IS NULL)
	BEGIN
		--| Расчёт базового веса. 
		SELECT 	
			@nBasicWeight =	(SELECT nBasicWeight FROM dbo.GetOperationValueBasicWeight(@nOperationId,po.nShippingWeight) )
		FROM dbo.Operations op
		LEFT JOIN (	SELECT nOperationId,
					SUM(po.nNetWeight) AS nShippingWeight
					FROM
					(
						SELECT
							op.nTypeOperationId,
							ISNULL(op.nParentOperationId, op.nOperationId)			    AS nOperationId,
							CASE WHEN po.nInputParameter = 0 THEN -1 ELSE 1 END * rb.nNetWeight AS nNetWeight
						FROM dbo.Operations op 
						INNER JOIN dbo.ParameterOperations po ON op.nOperationId = po.nOperationId
						INNER JOIN dbo.RegisterBoxes rb ON rb.nRegisterBoxId = po.nRegisterBoxId
						WHERE op.nTypeOperationId IN (-4)
						UNION ALL
							SELECT -4,
								bw.nOperationLoadingId,
								bw.nWeight
							FROM dbo.BigBagsWeighting bw
					) po
				GROUP BY po.nOperationId	) 
				po ON po.nOperationId = op.nOperationId
		WHERE op.nTypeOperationId = -4	
		AND   op.nOperationId = @nOperationId
	END
	
	SELECT 
		@nBasicWeightOut = ISNULL(@nBasicWeight,0),
		@nNetWeightOut   = ISNULL(@nNetWeightOut,0)
		
END TRY
BEGIN CATCH
	
	DECLARE @cUserErrMessage NVARCHAR(200) = 
			Char(10) + 'Ошибка в процедуре "GetCertificateBasicWeight" (см.:' + @@servername + '\' + DB_NAME() + '). ';
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
	
END CATCH							
GO

