--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('rptAnodeReportDay') IS NOT NULL
	DROP PROCEDURE dbo.rptAnodeReportDay
GO
-->*********************************************************************************************<--
--> Процедура получения расхода электродной массы за сутки (+ приход и расход с начала месяца).
-->
--> Автор: Бурденко Р.Л.
--> Ред.:				Пантелеев М.Ю. Пантелеев М.Ю.
-->	Дата:  06.11.2012	09.06.2015г.   02.07.2015г.
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.rptAnodeReportDay
(
	@dDateIn	DATETIME
)
AS
BEGIN
	--| Ред.: Пантелеев М.Ю.
	--| Дата: 09.06.2015г.
	--| Закомментировал создание "@dt1" т.к. оно нигде в теле ХП не используется.
	--DECLARE @dt1 DATE = CAST(DATEADD(DAY,-1*DATEPART(DAY,dbo.GetDtForTimeZone(@dDateIn)),dbo.GetDtForTimeZone(@dDateIn)) AS DATE)
	DECLARE @dt2 DATE = CAST(dbo.GetDtForTimeZone(@dDateIn) AS DATE)
	IF OBJECT_ID('tempdb..#tRes') IS NOT NULL DROP TABLE #tRes
	IF OBJECT_ID('tempdb..#tInc') IS NOT NULL DROP TABLE #tInc
	
	SELECT
		apr.nAnodeReportId,
		apr.nMaterialId,
		CASE 
			WHEN dc.cNameContr IS NULL THEN dm.cNameMaterial
			ELSE dc.cNameContr +' ('+dm.cNameMaterial+')'
		END AS cNameMaterial,
		ISNULL(dm.nParentMaterialId,dm.nMaterialId) AS nParentMaterialId,
		ISNULL(dmp.cNameMaterial,dm.cNameMaterial)  AS cParentMaterial,
		apr.nIncomeWeight,
		--(SELECT SUM(nIncomeWeight) FROM dcAnodeReportTable WHERE dDate BETWEEN @dt1 AND @dt2 AND nMaterialId = apr.nMaterialId) AS nIncome,
		su.nUnitId,
		su.cNameUnit,
		apr.nConsumedWeight AS nConsumed,
		apr.nRemainsWeight  AS nRemains,
		--| Добавил: Пантелеев М.Ю.
		--| Дата: 09.06.2015г.
		--| BTS: ****.
		COALESCE(apr.nRemainsWeightManualModif, apr.nRemainsWeight) AS nRemainsWeightManualModif,
		cUserNameManualModif = CASE app.nIsShow WHEN 1 THEN apr.cUserNameManualModif END,
		dDateManualModif     = CASE app.nIsShow WHEN 1 THEN apr.dDateManualModif END
		INTO #tRes
	FROM dcAnodeReportTable   AS apr
	LEFT JOIN dcAnodeSupplier AS aps ON aps.nMaterialId = apr.nMaterialId
	JOIN dctMaterial	  AS dm  ON dm.nMaterialId = apr.nMaterialId
	LEFT JOIN dctMaterial     AS dmp ON dmp.nMaterialId = dm.nParentMaterialId
	LEFT JOIN dctUnits	  AS su  ON su.nUnitId = apr.nUnitId
	LEFT JOIN dctContractor   AS dc  ON dc.nContractorId = aps.nContractorId
	OUTER APPLY (SELECT CASE
				WHEN (apr.nRemainsWeightManualModif IS NOT NULL) 
				 AND (apr.nRemainsWeight != nRemainsWeightManualModif) THEN 1 ELSE 0
			   END AS nIsShow
		    ) AS app
	WHERE apr.dDate = @dt2
	
	--| Ред.: Пантелеев М.Ю.
	--| Дата: 09.06.2015г., 02.07.2015г.
	--| BTS: ****.
	DECLARE @totalRemains  DECIMAL(10,3) = (SELECT SUM(T.nRemainsWeightManualModif)  FROM (SELECT DISTINCT ISNULL(nRemainsWeightManualModif,0) AS nRemainsWeightManualModif, cNameMaterial FROM #tRes) T )
	DECLARE @totalIncome   DECIMAL(10,3) = (SELECT SUM(T.nIncome)   FROM (SELECT DISTINCT ISNULL(nIncomeWeight,0) AS nIncome, cNameMaterial FROM #tRes) T )
	DECLARE @totalConsumed DECIMAL(10,3) = (SELECT SUM(T.nConsumed) FROM (SELECT DISTINCT ISNULL(nConsumed,0) AS nConsumed, cNameMaterial FROM #tRes) T )
		
	SELECT DISTINCT
		nParentMaterialId,
		nIncomeWeight,
		nRemainsWeightManualModif
	INTO #tInc	
	FROM #tRes
		
	SELECT
		r.*,
		@totalIncome   AS nTotalIncome,
		@totalConsumed AS nTotalConsumed,
		@totalRemains  AS nTotalRemains,
		(SELECT SUM(ISNULL(nConsumed,0))     FROM #tRes WHERE nParentMaterialId = r.nParentMaterialId) AS nParentConsume,
		(SELECT SUM(ISNULL(nIncomeWeight,0)) FROM #tInc WHERE nParentMaterialId = r.nParentMaterialId) AS nParentIncome,
		--| Ред.: Пантелеев М.Ю.
		--| Дата: 09.06.2015г.
		--| BTS: ****.
		(SELECT SUM(ISNULL(nRemainsWeightManualModif,0)) FROM #tInc WHERE nParentMaterialId = r.nParentMaterialId) AS nParentRemains
	FROM #tRes r

	
	IF OBJECT_ID('tempdb..#tRes') IS NOT NULL DROP TABLE #tRes
	IF OBJECT_ID('tempdb..#tInc') IS NOT NULL DROP TABLE #tInc
	
END
GO

