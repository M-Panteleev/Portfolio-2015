--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('AlterCertificateSequenceValueProbe') IS NOT NULL
	DROP PROCEDURE dbo.AlterCertificateSequenceValueProbe
GO

-->**************************************************************************************************<--
--> Процедура выполняет cортировку хим. состава сертификата в соответствии  с 
--> порядком следования хим компонентов.
-->
-->	Автор: Пантелеев М.Ю.
-->	Ред.		     Пантелеев М.Ю.
-->	Дата:  18.12.2014г.  15.01.2015г.
-->**************************************************************************************************<--

CREATE PROCEDURE dbo.AlterCertificateSequenceValueProbe (
	@nCertificateIdIn INT = NULL,	       --| Идентификатор сертификата
	@nMaterialIdIn    INT = NULL,	       --| Идентификатор типа материала.
	@cValueProbeIn	  NVARCHAR(MAX) = NULL --| Текущий хим состав сертификата.
) 

AS
BEGIN TRY
	IF @nCertificateIdIn IS NOT NULL
	BEGIN
		DECLARE
			@nMaterialId     INT,	        --| Идентификатор марки материала.
			@nMaterialTypeId INT,	        --| Идентификатор типа материала.
			@cValueProbe1	 NVARCHAR(MAX), --| Текущий хим состав сертификата.
			@cValueProbe2	 NVARCHAR(MAX)  --| Текущий хим состав сертификата отсортированный		
							--| по порядку следования хим компонентов.
		SET @nMaterialId  = @nMaterialIdIn
		SET @cValueProbe1 = @cValueProbeIn
		
		--| Получение данных сертификата(если они не были переданы во входных параметрах). 			
		IF (@nMaterialId  IS NULL)
		OR (@cValueProbe1 IS NULL)
		BEGIN
			SELECT @cValueProbe1 = CONVERT(NVARCHAR(MAX),xValueProbe), --| Текущий хим состав сертификата.
			       @nMaterialId  = nMaterialId			   --| Идентификатор марки материала.
			FROM dbo.Certificate WHERE nCertificateId = @nCertificateIdIn	
		END
		
		--| Получение id типа материала.
		SET @nMaterialTypeId = (SELECT t.nMaterialTypeId 
					FROM dbo.dctMaterial t 
					WHERE t.nMaterialId = dbo.GetFirstMatParent(@nMaterialId))
		
		--| Создание промежуточной переменной для преобразования
		--| входного хим. анализа в XML и затем его чтение через ".nodes" (см. ниже).
		DECLARE @xValueProbe XML = CONVERT(XML,@cValueProbe1)
		
		--| Сортировка текущего хим. состава сертификата в соответствии  с порядком следования хим компонентов.
		SET @cValueProbe2 = 
			CONVERT (NVARCHAR(MAX),(SELECT 
							t.c.query('./nParametrId').value('.','INT')		 AS nParametrId,
							t.c.query('./cNameParametr').value('.','NVARCHAR(300)')  AS cNameParametr,
							t.c.query('./cValueParametr').value('.','NVARCHAR(300)') AS cValueParametr
						FROM @xValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
						LEFT JOIN dbo.dctMatParamLink AS mpl ON  (mpl.nParametrId = t.c.query('./nParametrId').value('.','INT'))
						  AND (mpl.nMaterialTypeId = @nMaterialTypeId)
						ORDER BY ISNULL(mpl.nSequence, 1024)
						FOR XML PATH(N'cResultProbe'), root(N'ProbeParameters')
						)
				)--| END CONVERT
		
		--| Если текущий хим. состав сертификата не соответствует утверждённому порядку следования хим. компонентов
		IF  (@cValueProbe1 IS NOT NULL)
		AND (@cValueProbe2 IS NOT NULL)
		AND (@cValueProbe1 != @cValueProbe2) 
		BEGIN
			--| Сохранение корректно отсортированного хим. состава.				
			BEGIN TRANSACTION
				UPDATE dbo.Certificate
				SET xValueProbe  = @cValueProbe2
				WHERE nCertificateId = @nCertificateIdIn
			COMMIT TRANSACTION
		END 
	END

END TRY
BEGIN CATCH

	IF XACT_STATE() <> 0
	BEGIN
		ROLLBACK TRANSACTION;
	END	
	
	DECLARE @cUserErrMessage  NVARCHAR(400) = 
				Char(10)+'Ошибка в процедуре "AlterCertificateSequenceValueProbe".'+ Char(10);
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
	
END CATCH							 	
GO

