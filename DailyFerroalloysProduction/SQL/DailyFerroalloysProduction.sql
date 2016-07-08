--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('DailyFerroalloysProduction') IS NOT NULL
	DROP PROCEDURE dbo.DailyFerroalloysProduction
GO
-->*********************************************************************************************<--
--> ХП отчета "Суточная сводка о выполнении плана производства ферросплавов".
-->
--> Автор: Пантелеев М.Ю.
--> Ред.:		  Пантелеев М.Ю. Пантелеев М.Ю.
--> Дата:  24.08.2015г.	  11.09.2015г.   16.09.2015г.
-->	
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.DailyFerroalloysProduction
(
	@dDateBeginIn DATETIME = NULL,
	@dDateEndIn   DATETIME = NULL
)
AS
BEGIN
	DECLARE @dDateBegin	     DATE = CAST(dbo.GetDtForTimeZone(@dDateBeginIn) AS DATE)
	DECLARE @dDateEnd	     DATE = CAST(dbo.GetDtForTimeZone(@dDateEndIn)   AS DATE)
	DECLARE @dDateBeginMonth     DATE = DATEADD(DAY, -DAY(@dDateBegin)+1, @dDateBegin)
	DECLARE @dDateBeginMonth_UTC DATETIME = dbo.GetDtToUTC(@dDateBeginMonth)
	
	DECLARE @nSummerTime BIT  --| Здесь будет летнее время (1 час, если есть).
	DECLARE @nUTCOffset  REAL --| Здесь будет смещение в часах относительно UTC для текущего часового пояса.
	
	--| Получение летнего времени и смещения относительно UTC 
	--| для текущего часового пояса пользователя.
	--| Необходимо для того, чтобы в запросах ниже отказаться от использования 
	--| функций "dbo.GetDtToUTC()", "dbo.GetDtForTimeZone()"
	--| т.к. они вызывают друг друга (см. "dbo.GetDtToUTC()") и рассчитывают смещение в часах
	--| при каждом вызове, а это ни к чему, один раз получили - потом используем. 
	--| Цель: сокращение времени выполнения ХП.
	SELECT 
		@nSummerTime = nSummerTime,	    --| Летнее время.
		@nUTCOffset = ISNULL(nUTCOffset, 0) --| Смещение в часах относительно UTC.
	FROM dbo.dctTimeZone			    --| Таблица справочник часовых поясов.
	WHERE nTimeZoneId = dbo.GetTimeZoneUser()   --| Поиск в таблице в соответствии с текущим часовым поясом.  
	
	--| Если для текущего часового пояса актуален перевод времени на летнее время.
	IF (@nSummerTime != 0)
	BEGIN
		--| Если начальная дата выборки отчёта не входит в интервал летнего времени 
		--| обнуляем "@nSummerTime".
		IF NOT EXISTS(
				SELECT 1 FROM dbo.dctSummerTime AS st
				WHERE st.nYear = DATEPART(YEAR, @dDateBegin)
					  AND @dDateBegin BETWEEN ISNULL(st.dBeginSummer,'19170711') AND ISNULL(st.dEndSummer,'26660101')	
					 )
		SET @nSummerTime = 0
	END
	--| Получаем смещение по времени относительно UTC 
	--| для текущего часового пояса пользователя с учётом летнего времени.
	SET @nUTCOffset = ISNULL(@nUTCOffset + @nSummerTime, 6);
	--| Значение переменной @nUTCOffset необходимо для конвертирования дат из текущего времени в UTC и обратно 
	--| без использования специализированных функций "dbo.GetDtToUTC()", "dbo.GetDtForTimeZone()"
	--| т.к. они вызывают друг друга (см. "dbo.GetDtToUTC()") и рассчитывают смещение при каждом вызове. 
	
	
	--| Удаление временной таблицы #tData_1, 
	--| если по каким-либо причинам, она не была удалена
	--| после предыдущего запуска ХП.
	IF OBJECT_ID('tempdb..#tData_1') IS NOT NULL 
	DROP TABLE #tData_1 
	--| Создание временной таблицы #tData_1.
	--| Таблица предназначена для временного хранения плановых и 
	--| фактических показателей производства по печам в разрезе смен 
	--| с начала месяца по заданную дату (план и факт будут храниться в разных записях текущей таблицы).
	CREATE TABLE #tData_1
	(
		dDate	     DATE,		   --| Дата производства;
		nShiftId     INT,		   --| ID смены;
		nUnitId	     INT,		   --| ID цеха;
		nEquipmentId INT,		   --| ID оборудования (печи);
		nMaterialId  INT,		   --| ID материала (сплава);
		nRemeltingMaterialId INT,          --| ID переплавляемого материала;
		nValue		     DECIMAL(9,3), --| Масса производства в метрических тоннах;
		nValueChrome     DECIMAL(9,3),     --| Масса производства в тоннах хрома;
		nIsRemelting     INT,		   --| Признак переплава: 0-обычная плавка, 1-переплав; 
		dDateUTC	 DATETIME,	   --| Дата производства в UTC (только для факта);
		dDateBegin	 DATETIME,	   --| Дата начала переплава в UTC (только для факта);
		dDateEnd	 DATETIME,	   --| Дата окончания переплава в UTC (только для факта);
		nIsPlan		 INT		   --| Признак плана: 0-факт, 1-план.
	)
	
	--| Наполнение временной таблицы #tData_1.
	INSERT INTO #tData_1
	--| Получение плана производства по печам в разрезе смен с начала месяца по заданную дату.
	SELECT 
		pln.dDatePlan AS dDate, --| Дата плана; 
		pln.nShiftId,		--| ID смены;
		pln.nUnitId,		--| ID цеха;
		pln.nEquipmentId,	--| ID оборудования (печи);
		pln.nMaterialId,        --| ID сплава;
		nRemeltingMaterialId =  --| ID переплавляемого материала; 
			CASE WHEN (pln.nIsRemelting = 1) THEN pln.nMaterialId  ELSE NULL END,
		SUM(pln.nValuePlan)	   AS nValue,	    --| Суточный план поизводства в метрических тоннах по каждой смене;
		SUM(pln.nValuePlanChrome)  AS nValueChrome, --| Суточный план поизводства в тоннах хрома по каждой смене;
		ISNULL(pln.nIsRemelting,0) AS nIsRemelting, --| Признак переплава: 0-обычная плавка, 1-переплав; 
		NULL AS dDateUTC,                           --| Пустое поле (необходимо для корректного объединения с запросом ниже);
		NULL AS dDateBegin,     --| Пустое поле (необходимо для корректного объединения с запросом ниже);
		NULL AS dDateEnd,       --| Пустое поле (необходимо для корректного объединения с запросом ниже);
		1 AS nIsPlan	        --| Признак плана: 0-факт, 1-план.
	FROM dbo.PlanProductionUnitDay  AS pln --| Таблица сменно-суточных планов производства ФСП.
	WHERE (pln.dDatePlan BETWEEN @dDateBeginMonth AND @dDateEnd) --| C начала месяца по заданную дату.
	  AND (pln.nEquipmentId IS NOT NULL)   --| Значение плана непустое.
	GROUP BY pln.dDatePlan, pln.nShiftId, pln.nUnitId, pln.nEquipmentId, pln.nMaterialId, pln.nIsRemelting
	
	UNION --| Объединение плана и факта.
	
	--| Получение факта производства по печам в разрезе смен с начала месяца по заданную дату.
	SELECT 
		rfp.dDateMelt As dDate,	    --| Дата выпуска продукции;
		rfp.nShiftId,		    --| ID смены;
		rfp.nUnitId, 		    --| ID цеха;
		rfp.nEquipmentId,	    --| ID оборудования (печи);
		mt.nMaterialId,		    --| ID сплава;
		mrd.nRemeltingMaterialId,   --| ID переплавляемого материала; 
		SUM(rfp.nWeight) AS nValue, --| Суточный объём производства печи в метрических тоннахпо каждой смене;
		nValueChrome =		    --| Суточный объём производства печи в тоннах хрома (только для ФХ) по каждой смене;
			SUM(CASE WHEN(dbo.GetTopParentMaterialId(rfp.nMaterialId) = 269) THEN rfp.nBasicWeight ELSE NULL END),
		ISNULL(mrd.nIsRemelting,0) AS nIsRemelting, --| Признак переплава: 0-обычная плавка, 1-переплав; 
		dt.dDateUTC,                --| Дата плавки в UTC (дата плавки + время конеца смены с переводом в UTC).
		mrd.dDateBegin,             --| Дата начала переплава (UTC);
		mrd.dDateEnd,               --| Дата окончания переплава (UTC);
		0 AS nIsPlan                --| Признак плана: 0-факт, 1-план.
	 FROM dbo.DailyFerroalloysProduction AS rfp               --| Таблица факта производства ФСП (наполняется данными из БД цехов).
	 LEFT JOIN dbo.dctShift AS s ON s.nShiftId = rfp.nShiftId --| Подключение справочника смен.
	 
	 --| Получение даты плавки.
	 --| В таблице "DailyFerroalloysProduction"(см. выше) даты плавок не имеют времени,
	 --| наличие времени необходимо для проверки входит плавка в интервал из журнала переплавов или нет.
	 --| т.е. если входит значит это переплав, а если не входит значит обычный выпуск.
	 --| В связи с этим, временем плавки условно считаем время окончания смены в которую 
	 --| эта плавка была произведена.
	 --| После того, как дата и время объединены, всё это переводится в UTC т.к. в журнале переплавов 
	 --| интервалы задаются в UTC формате. 
	 CROSS APPLY(SELECT dDateUTC = DATEADD(HOUR, -(@nUTCOffset),(CONVERT(DATETIME, CONVERT(DATETIME,rfp.dDateMelt)+' '+DATEADD(MINUTE,-1,s.dEndTime))))
				 FROM dbo.dctShift AS s 
				 WHERE s.nShiftId = rfp.nShiftId 
				) AS dt
				
	 --| Проверка является ли факт выплавки переплавом.
	 OUTER APPLY
		 ( 
			SELECT TOP(1) 
				--| Плавка является переплавом;
				1 AS nIsRemelting, 
				--| ID переплавляемого материала;
				md.nMaterialId AS nRemeltingMaterialId,
				--| Дата начала переплава в UTC (необходимо для расчёта затрат электроэнергии на переплав);
				dDateBegin = DATEADD(HOUR, -(@nUTCOffset),(CONVERT(DATETIME, CONVERT(DATETIME,rfp.dDateMelt)+' '+s.dBeginTime))),
				--| Дата окончания переплава в UTC (необходимо для расчёта затрат электроэнергии на переплав);
				dDateEnd = DATEADD(HOUR, -(@nUTCOffset),(CONVERT(DATETIME, CONVERT(DATETIME,rfp.dDateMelt)+' '+s.dEndTime)))
			FROM dbo.mcRemeltingDocument AS md --| Таблица переплавов, содержит список интервалов времени 
							   --| (начало и окончание) переплавных компаний цехов 
							   --| по печам и сплавам (заполняется в документе "Журнал переплавов" на Главном сервере.).
			WHERE 
			  --| Печь плавки = печи из журнала;
				  (md.nEquipmentId = rfp.nEquipmentId) 
			  --| Дата плавки входит в интервал из журнала;
			  AND (dt.dDateUTC BETWEEN md.dDateBegin AND md.dDateEnd)
			  --| Запись в журнале актуальна (не удалена).
			  AND (md.nIsDel = 0) 
			ORDER BY md.dLastEdit DESC
			
		 ) mrd
	
	--| OUTER APPLY ниже необходим для группировки переплавов по материалу, 
	--| иначе не удастся получить суточный объём производства печи (как сумму по сменам).
	OUTER APPLY (SELECT COALESCE(mrd.nRemeltingMaterialId, rfp.nMaterialId) AS nMaterialId) As mt
	
	--| Выборка факта производства ФСП осуществляется по критериям:
	WHERE (rfp.dDateMelt BETWEEN @dDateBeginMonth AND @dDateEnd) --| Все плавки с начала месяца по текущую дату.
	GROUP BY --| Группировка необходима для получения суммы в разрезе смен (суточного объём производства);
		rfp.dDateMelt, rfp.nShiftId, rfp.nUnitId, rfp.nEquipmentId, mt.nMaterialId,
		mrd.nRemeltingMaterialId, mrd.nIsRemelting, dt.dDateUTC, mrd.dDateBegin, mrd.dDateEnd
	
	--| Удаление ненужных записей из временной таблицы #tData_1.
	--| Удаляются записи с планом производства родительских (не марочных) сплавов.
	--| В результате, в таблице #tData_1 останется весь факт, а из плана
	--| только по марочному ФХС(ФХС40,ФХС48),ФС(ФС75) и переплаву + в качестве исключения, 
	--| останутся записи с планом по родительским сплавам для печей, 
	--| у которых нет фактической выплавки (чтобы вне зависимости от факта 
	--| (когда нет данных по маркам) в отчёте отображался план производства по печи).
	DELETE FROM #tData_1 
	FROM #tData_1 AS td
	--| Получение ID родительского материала записи
	CROSS APPLY(SELECT nParentMaterialId  FROM dbo.dctMaterial  AS dm where dm.nMaterialId = td.nMaterialId) dm
	--| Проверка наличия факта выплавки печи
	CROSS APPLY(SELECT COUNT(nEquipmentId) AS cntFact 
				FROM #tData_1 
				WHERE (nIsPlan = 0) AND (nEquipmentId = td.nEquipmentId)
				) ap
	--| Из таблицы #tData_1 удаляются записи если:
	WHERE (dm.nParentMaterialId IS NULL) --| у материала нет родителя (он сам и есть родитель)
	  AND (nIsPlan = 1)	   	     --| запись является планом производства
	  AND (nIsRemelting != 1) --| это не переплав (Добавил: Пантелеев М.Ю., Дата: 11.09.2015г.)
	  AND (ap.cntFact > 0) 	  --| у печи есть фактический выпуск
	
	--SELECT * FROM #tData_1 
	--ORDER BY NEquipmentId
		
	--| Удаление временной таблицы #tData_2, 
	--| если по каким-либо причинам, она не была удалена
	--| после предыдущего запуска ХП.
	IF OBJECT_ID('tempdb..#tData_2') IS NOT NULL 
	DROP TABLE #tData_2 
	--| Создание временной таблицы #tData_2.
	--| Таблица предназначена для временного хранения детальных данных: 
	--|  - производства (план, факт);
	--|  - расхода электроэнергии (план, факт);
	--|  - норм;
	--| и других, необходимых для формирования отчёта данных,
	--|	по печам в разрезе суток для всех марок продукции 
	--|	с начала месяца по заданную дату.
	--|	В данной таблице плановые и фактические показатели печи будут
	--|	агрегироваться в суточный итог по маркам каждой печи (общая сумма всех смен)
	--|	и собираться в одну запись, а не в двух (план/факт) как это реализовано в #tData_1.
	--|	Таблица предназначена для хранения детальной информации в разрезе марок и печей.
	CREATE TABLE #tData_2
	( 
		dDate		      DATE,	    --| Дата производства;
		nUnitId		      INT,	    --| ID цеха;
		cNameUnit	      NVARCHAR(100),--| Название цеха;
		nEquipmentId	      INT,	    --| ID оборудования (печи);
		cNameEquipment	      NVARCHAR(100),--| Название печи;
		nParentMaterialId     INT,	    --| ID корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
		cNameParentMaterial   NVARCHAR(100),--| Название корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
		nMaterialOrParentMaterialId INT,    --| ID марки материала ФХС40,ФХС48 либо ID корневого материала-родителя (для всех остальных сплавов); 
		nMaterialId		    INT,    --| ID материала;
		cNameMaterial	      NVARCHAR(100),--| Название материала;
		nMarkId		      INT,	    --| ID марки материала (для всех сплавов);
		cNameMark	      NVARCHAR(300),--| Название марки материала;
		nValuePlan	      DECIMAL(9,3), --| План производства(сутки);
		nValue		      DECIMAL(9,3), --| Факт производства(сутки);
		nValueMark	      DECIMAL(9,3), --| Факт производства(сутки);
		nValuePlanMonth       DECIMAL(9,3), --| План производства с начала месяца;
		nValueMonth	      DECIMAL(9,3), --| Пустое поле (необходимо для корректной операции UNION);
		nValueMarkMonth	      DECIMAL(9,3), --| Факт производства с начала месяца;
		nValueEnergyPlan      DECIMAL(9,3), --| План расхода электроэнергии(сутки);
		nValueEnergy	      DECIMAL(9,3), --| Факт расхода электроэнергии(сутки);
		nValueEnergyPlanMonth DECIMAL(9,3), --| План расхода электроэнергии с начала месяца;
		nValueEnergyMonth     DECIMAL(9,3), --| Факт расхода электроэнергии с начала месяца;
		nValueEnergyNormMin   DECIMAL(9,3), --| Норма расхода электроэнергии(не min не max просто норма, название обусловлено UNION);
		nValueEnergyNormMax   DECIMAL(9,3), --| Пустое поле (необходимо для корректной операции UNION);
		nIsRemelting	      INT	    --| Признак переплава: 0-обычная плавка, 1-переплав; 
	)
	
	--| Наполнение временной таблицы #tData_2.
	INSERT INTO #tData_2
	--| Выборка данных: 
	--|  - производства (план, факт);
	--|  - расхода электроэнергии (план, факт);
	--|  - норм;
	--| и других, необходимых для формирования отчёта данных 
	--|	по печам в разрезе суток для всех марок продукции 
	--|	с начала месяца по заданную дату.
	--|	Плановые и фактические показатели печи агрегируются в суточный итог 
	--|	по маркам каждой печи (общая сумма всех смен) и собираются  
	--|	в одну запись, а не храниться в двух (план/факт) как это реализовано в #tData_1.
	--| Таблица #tData_2 - представляет собой более высокий уровень представления данных 
	--| на основе #tData_1 + дополнительные данные по электроэнергии, нормам и пр. 
		SELECT 
			rfp.dDate	  AS dDate,             --| Дата производства;
			un.nParentUnitId  AS nUnitId,           --| ID цеха;
			unp.cNameUnit,		                --| Название цеха;
			rfp.nEquipmentId,	                --| ID оборудования (печи);
			eq.cNameEquipment,	                --| Название печи;
			rfp.nParentMaterialId,	                --| ID корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
			ma.cNameMaterial AS cNameParentMaterial,--| Название корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
			rfp.nMaterialOrParentMaterialId,        --| ID марки материала (ФХС40,ФХС48,ФС75)  
								--| либо ID корневого материала-родителя (ФХ,ФСМн);
			--| ID материала;
			nMaterialId = CASE WHEN (rfp.nIsRemelting = 0) THEN ma.nMaterialId ELSE -ma.nMaterialId END,
			--| Название материала;
			cNameMaterial = CASE WHEN (rfp.nIsRemelting = 0) THEN ma.cNameMaterial ELSE 'Переплав' END,
			rfp.nMaterialId	     AS nMarkId,	 --| ID марки материала (для всех сплавов);
			rfp.cNameMaterial    AS cNameMark,	 --| Название марки материала;
			rfp.nValuePlan	     AS nValuePlan,	 --| План производства(сутки);
			rfp.nWeight	     AS nValue,		 --| Факт производства(сутки);
			rfp.nWeight	     AS nValueMark,	 --| Факт производства(сутки);
			ap3.nValuePlanMonth  AS nValuePlanMonth, --| План производства с начала месяца;
			NULL		     AS nValueMonth,     --| Пустое поле (необходимо для корректной операции UNION);
			ap3.nValueMarkMonth,                     --| Факт производства с начала месяца;
			ap3.nValueEnergyPlan,                    --| План расхода электроэнергии(сутки);
			rfp.nValueEnergy,	                 --| Факт расхода электроэнергии(сутки);
			ap3.nValueEnergyPlanMonth,               --| План расхода электроэнергии с начала месяца;
			rfp.nValueEnergyMonth,	                 --| Факт расхода электроэнергии с начала месяца;
			mr.nValueEnergyNorm  AS nValueEnergyNormMin, --| Норма расхода электроэнергии(не min не max просто норма, название обусловлено UNION);
			NULL		     AS nValueEnergyNormMax, --| Пустое поле (необходимо для корректной операции UNION);
			rfp.nIsRemelting --| Признак переплава: 0-обычная плавка, 1-переплав; 
		FROM(
				SELECT
					ct.dDate,	       --| Дата производства;		  
					ct.nUnitId,	       --| ID дочернего подразделения (по нему будет найден родитель - цех);
					ct.nEquipmentId,       --| ID оборудования (печи);  
					ma.nMaterialId,	       --| ID марки материала;
					app.nParentMaterialId, --| ID корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);		
					ct.nIsRemelting,       --| Признак переплава: 0-обычная плавка, 1-переплав;
					ap.nMaterialOrParentMaterialId, --| ID марки материала (ФХС40,ФХС48,ФС75) либо 
									--| ID корневого материала-родителя (ФХ,ФСМн);
					SUM(ea.nValueEnergy) AS nValueEnergy, --| Факт расхода электроэнергии на переплав 
									      --| за сутки (общая сумма расхода всех смен 
									      --| по печи за сутки);
					SUM(ea.nValueEnergyMonth) AS nValueEnergyMonth, --| Факт расхода электроэнергии на переплав 
											--| с начала месяца (общая сумма расхода всех
											--| смен по печи с начала месяца);
					--| Название марки материала;
					cNameMaterial = CASE WHEN (ct.nIsRemelting = 0) THEN ma.cNameMaterial ELSE 'Переплав ' + ma.cNameMaterial END,
					--| Факт производства за сутки (общая сумма всех смен по печи); 
					nWeight = SUM(CASE WHEN (ct.nIsPlan = 0) AND (app.nParentMaterialId  = 269) THEN ct.nValueChrome --| Для ФХ в тоннах хрома;
									   WHEN (ct.nIsPlan = 0) AND (app.nParentMaterialId != 269) THEN ct.nValue --| Для всех НЕ ФХ - в метрических тоннах.
						      END),
					--| План производства за сутки (общая сумма всех смен по печи);
					nValuePlan = SUM(CASE WHEN (ct.nIsPlan = 1) AND (app.nParentMaterialId  = 269) THEN ct.nValueChrome --| Для ФХ в тоннах хрома;
										  WHEN (ct.nIsPlan = 1) AND (app.nParentMaterialId != 269) THEN ct.nValue --| Для всех НЕ ФХ - в метрических тоннах.
							 END)
				FROM #tData_1 AS ct
				--| Получение названия марки материал по его ID.
				LEFT JOIN dbo.dctMaterial  AS ma ON ma.nMaterialId = COALESCE(ct.nRemeltingMaterialId, ct.nMaterialId)
				--| Получение ID корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
				CROSS APPLY (SELECT dbo.GetTopParentMaterialId(ct.nMaterialId) AS nParentMaterialId ) AS app
				--| Получение названия марки материала(ФХС40,ФХС48,ФС75) либо родителя (ФХ,ФСМн)
				--| в зависимости от родительского ID.
				LEFT JOIN dbo.dctMaterial  AS dm ON dm.nMaterialId = 
					(SELECT CASE 
							WHEN (app.nParentMaterialId = 261) --| если это ФХС 
							  OR (app.nParentMaterialId = 301) --| или ФС  
							THEN  ct.nMaterialId		   --| тогда возврщаем марку (ФХС40, ФХС48, ФС75)
							ELSE  app.nParentMaterialId        --| иначе, Id родительского материала (ФХ,ФСМн)
							END
					)
				--| Получение ID марки переплавляемого материала, либо 
				--| ID корневого материала-родителя для обычных плавок (не переплава);
				CROSS APPLY 
					(SELECT CASE 
							WHEN ct.nIsRemelting = 0 THEN dm.nMaterialId 
							ELSE ma.nMaterialId 
							END AS nMaterialOrParentMaterialId
 					 ) ap
							 
				--| Получение расхода электроэнергии на переплав.
				OUTER APPLY
				( 
					SELECT 
						--| Получение суточного расхода электроэнергии на переплав в разрезе смен;
						SUM(t.nValueEnergy) AS nValueEnergy,
						--| Получение расхода электроэнергии на переплав в разрезе смен с начала месяца;
						SUM(t.nValueEnergyMonth) AS nValueEnergyMonth
					FROM(
						--| Выборка записей из таблицы расхода электроэнергии входящих 
						--| в интервалы переплавных компаний (по печам).
						SELECT 
							--| Получение суточного расхода электроэнергии на переплав;
							nValueEnergy =	    SUM(CASE WHEN (mea.dDate BETWEEN @dDateBeginIn AND @dDateEndIn) THEN mea.nValueActive END), 
							--| Получение расхода электроэнергии на переплав с начала месяца ;
							nValueEnergyMonth = SUM(CASE WHEN (mea.dDate BETWEEN @dDateBeginMonth_UTC AND @dDateEndIn) THEN mea.nValueActive END)
						FROM dbo.mcEnergyAccount AS mea --| Таблица расхода электроэнергии(наполняется авт. данными из БД цехов во время синх-ции).
						
						--| Получение полного списка переплавов с начала месяца.
						--| Цель: получение интервалов времени переплавных компаний.
						CROSS APPLY
							(
								SELECT 
									td.dDate,		--| Дата производства(выпуска плавки);
									td.nEquipmentId,	--| ID оборудования (печи); 
									td.nShiftId,		--| ID смены;
									td.dDateBegin,		--| Дата начала переплава (UTC);
									td.dDateEnd,		--| Дата окончания переплава (UTC);
									td.nRemeltingMaterialId --| ID переплавляемого материала; 
								FROM #tData_1 AS td
								WHERE
								  --| Критерии выборки из #tData_1:
								  --| Искомая запись является переплавом;
									  (td.nIsRemelting = 1) 
								  --| Текущей запись из внешней выборки является переплавом;
								  AND (ct.nIsRemelting = 1) 
								  --| Искомая запись является фактом производства;
								  AND (td.nIsPlan = 0)	  
								  --| Искомая запись обладает весом (значение непустое); 
								  AND (COALESCE (td.nValueChrome,td.nValue) IS NOT NULL) 
								  --| Искомая запись имеет ID печи = ID печи 
								  --| текущей записи из внешней выборки;
								  AND (td.nEquipmentId = ct.nEquipmentId) 
								  --| Материал переплава искомой записи = материалу перепла 
								  --| текущей записи из внешней выборки;
								  AND (td.nRemeltingMaterialId = ct.nRemeltingMaterialId)
								  --| Искомая запись имеет ID смены = ID смены 
								  --| текущей записи из внешней выборки;
								  AND (td.nShiftId = ct.nShiftId) 
								GROUP BY td.dDate, td.nEquipmentId, td.nShiftId, td.dDateBegin, td.dDateEnd, td.nRemeltingMaterialId 
							) ap
						WHERE 
						  --| Условия выборки:
						  --| Дата-время записи о расходе электроэнергии (поле "mea.dDate" из табл. "dbo.mcEnergyAccount")
						  --| входит в интервал переплавной компании "ap.dDateBegin" - "ap.dDateEnd";
							  (mea.dDate BETWEEN ap.dDateBegin and ap.dDateEnd)
						  --| Активная мощность не может быть больше 100 МВт⋅ч,
						  --| подобные записи ошибочны, они не берутся;
						  AND (mea.nValueActive < 100)
						  --| Искомая запись имеет ID печи = ID печи 
						  --| текущей записи из внешней выборки;
						  AND (mea.nEquipmentId = ap.nEquipmentId)
						  --| Текущей запись из внешней выборки является фактом производства;
						  AND (ct.nIsPlan = 0)
						GROUP BY ap.dDate, ap.nEquipmentId
							
					    ) t
				) AS ea

				WHERE --| Из табл."#tData_1 AS ct" отбираются записи с начала месяца по заданную дату.
				      --| Условие ниже можно было бы опустить т.к. табл. "#tData_1" и так содержит данные 
				      --| в необходимом интервале, но в случае изменения критериев наполнения табл. "#tData_1" 
				      --| условие ниже будет полезным.
				      (ct.dDate BETWEEN @dDateBeginMonth AND @dDateEnd)
					 
				GROUP BY --| Группировка необходима для суммирования объёмов производства (план/факт)
					 --| (общая сумма производства всех смен за сутки по печи);
					 --| и суммы показателей расхода электроэнергии на переплав
					 --| (общая сумма расхода эл.энергии всех смен за сутки и с начала месяца);
					 ct.dDate, ct.nUnitId, ct.nEquipmentId, ma.nMaterialId,
					 ma.cNameMaterial, app.nParentMaterialId, ap.nMaterialOrParentMaterialId, ct.nIsRemelting
					
			) AS rfp --| конец блока FROM(..) AS rfp.
			
			--| Получение названия печи.
			OUTER APPLY(SELECT cNameEquipment, nUnitId FROM dbo.Equipments WHERE nEquipmentId = rfp.nEquipmentId) AS eq
			--| Получение ID цеха-родителя.
			OUTER APPLY(SELECT nParentUnitId FROM dbo.stUnit  WHERE nUnitId = eq.nUnitId) AS un
			--| Получение названия цеха-родителя.
			OUTER APPLY(SELECT nUnitId, cNameUnit FROM dbo.stUnit  WHERE nUnitId = un.nParentUnitId) AS unp
			--| Получение названия материала родителя.
			OUTER APPLY(SELECT nMaterialId, cNameMaterial FROM dbo.dctMaterial  WHERE nMaterialId = rfp.nParentMaterialId) AS ma
			
			
			--| Получение норм по электроэнергии.
			OUTER APPLY
				(
					SELECT TOP(1) (rt.nDecimalValue * 1.0) AS nValueEnergyNorm 
					FROM dbo.mcRateDocument AS rd --| Таблица документов норм.
					--| Подключение таблицы значений норм.
					LEFT OUTER JOIN dbo.mcRate  AS rt ON rt.nRateDocumentId = rd.nRateDocumentId
					WHERE (rd.nRateTypeId IN(-4,-11) ) --| nRateTypeId = -4  - Нормы расхода электроэнергии.
													   --| nRateTypeId = -11 - Нормы расхода электроэнергии на переплав. 
					  AND (rfp.dDate BETWEEN rd.dDateBegin AND rd.dDateEnd) 
					  AND (rt.nUnitId IS NULL OR rt.nUnitId = unp.nUnitId) 
					  AND (rt.nEquipmentId IS NULL OR rt.nEquipmentId = rfp.nEquipmentId) 
					  AND (rt.nMaterialProductionId = rfp.nMaterialOrParentMaterialId) 
					ORDER BY	
						(CASE WHEN rt.nMaterialProductionId = rfp.nParentMaterialId THEN 4 ELSE 0 END +
						 CASE WHEN rt.nEquipmentId = rfp.nEquipmentId THEN 2 ELSE 0 END +
						 CASE WHEN rt.nUnitId = unp.nUnitId 		  THEN 1 ELSE 0 END +
						 CASE WHEN (rfp.nIsRemelting = 1) AND (rd.nRateTypeId = -11)THEN 1 ELSE 0 END) DESC,
						 rd.dDateBegin DESC
				) mr
			
			--| Проверка, существует ли более актуальная запись по сравнению с текущей из rfp.
			--| Если "nIsExistsActualData" IS NULL - значит, текущая запись из rfp
			--| самая последняя (в интервале с начала месяца по заданную дату), поэтому, 
			--| в OUTER APPLY "ap3" (см. ниже) будет выполнен суммарный расчёт объёма производства(план,факт)
			--| текущей марки и печи с начала месяца  
			--| и суммарный расчёт планового расхода электроэнергии на переплав (если он есть)
			--| для текущего сплава и печи с начала месяца.
			--| Статус "nIsExistsActualData" необходим для того чтобы: 
			--| во-первых, не выполнять расчёт производственных показателей с начала месяца
			--| для всех записей выборки из "rfp",
			--| во-вторых для корректного отображения данных в файле отчёта.
			OUTER APPLY
				( 
					SELECT TOP(1) 1 AS nIsExistsActualData 
					FROM #tData_1 as td 
					WHERE (td.nEquipmentId = rfp.nEquipmentId) 
					  AND (COALESCE (td.nRemeltingMaterialId, td.nMaterialId) = rfp.nMaterialId)
					  AND (td.nIsRemelting = rfp.nIsRemelting)
					  AND (td.dDate > rfp.dDate)
				) AS ap4
			
			--| Получение суммарного объёма производства(план,факт) текущей марки и печи с начала месяца +
			--| расчёт суммарного планового расхода электроэнергии на переплав (если он есть)
			--| для текущего сплава и печи с начала месяца.
			OUTER APPLY
				( 
					SELECT 
						--| Расчёт фактического суммарного объёма производства текущей марки и печи 
						--| с начала месяца;
						nValueMarkMonth  = SUM(CASE WHEN (td.nIsPlan = 0) AND (en.nIsExistsActualData IS NULL ) THEN COALESCE (td.nValueChrome,td.nValue) END), --| В тн. хром для ФХ, в метрических для других сплавов.
						--| Расчёт планового объёма производства текущей марки и печи с начала месяца;
						nValuePlanMonth  = SUM(CASE WHEN (td.nIsPlan = 1) AND (en.nIsExistsActualData IS NULL)  THEN td.nValue END),
						--| Получение планового суточного расхода эл.энергии на переплав по текущей печи;
						--| Рассчитывается как: факт выпуска за сутки * норму эл. энергии / 1000;
						nValueEnergyPlan = SUM(CASE WHEN (td.nIsPlan = 0) AND (td.nIsRemelting = 1) AND (en.nIsRemelting = 1) AND (td.dDate BETWEEN @dDateBegin AND @dDateEnd) THEN td.nValue * en.nValueEnergyNorm / 1000.0 ELSE NULL END),
						--| Получение планового расхода эл.энергии на переплав с начала месяца.
						--| Рассчитывается как: факт выпуска с начала месяца * норму эл. энергии / 1000;
						nValueEnergyPlanMonth = SUM(CASE WHEN(td.nIsPlan = 0) AND (en.nIsExistsActualData IS NULL) AND (en.nIsRemelting = 1) THEN td.nValue * en.nValueEnergyNorm / 1000.0 ELSE NULL END)
					FROM #tData_1 AS td, 
						--| Заводим внешние значения в запрос т.к. в статических функциях (SUM) 
						--| использовать внешние ссылки нельзя.
						(SELECT mr.nValueEnergyNorm, ap4.nIsExistsActualData, rfp.nIsRemelting) AS en 
					WHERE 
					  --| Условия выборки:
					  --| ID подразделения искомой записи = ID подразделения текущей записи
					  --| из внешней выборки;
						  (td.nUnitId = rfp.nUnitId) 
					  --| ID печи искомой записи = ID печи текущей записи
					  --| из внешней выборки;
					  AND (td.nEquipmentId = rfp.nEquipmentId)
					  --| ID материала искомой записи = ID материала текущей записи
					  --| из внешней выборки;
					  AND (COALESCE (td.nRemeltingMaterialId, td.nMaterialId) = rfp.nMaterialId)
					  --| Признак переплава искомой записи = признаку переплава текущей записи 
					  --| из внешней выборки (0-обычная плавка, 1-переплав);
					  AND (td.nIsRemelting = rfp.nIsRemelting)
					  --| Дата искомой записи входит в интервал с начала месяца по заданную дату.
					  AND (td.dDate BETWEEN @dDateBeginMonth AND @dDateEnd)
					GROUP BY td.nUnitId, td.nEquipmentId 
				) AS ap3
		
		--SELECT * FROM #tData_2 
		--ORDER BY NEquipmentId
		
		--|--------------------------------------------------------------------------------------------
		--| ФИНАЛЬНАЯ выборка данных отчёта.
		--| Состоит из двух запросов объединённых операцией UNION.
		--|	1) Выборка детальных данных о производстве(план/факт), эл. энергии(план/факт) и нормах
		--|	   в разрезе марок и печей; 
		--|	2) Выборка итоговых(агрегированных) данных о фактическом и плановом производстве, 
		--|	   расходе эл. энергии и нормах по каждой печи + итоги по печам с начала месяца.


		--| 1) Выборка детальных данных о производстве(план/факт), эл. энергии(план/факт) и нормах
		--| в разрезе марок и печей. 
		SELECT * FROM #tData_2 WHERE COALESCE(nValueMarkMonth, nValuePlanMonth) IS NOT NULL
		
		UNION --| Объединение детальных и итоговых данных отчёта.
		
		--| 2) Получение итоговых(агрегированных) данных о производстве, эл. энергии и нормах
		--| по каждой печи + итоги по печам с начала месяца. 
		SELECT 
			NULL AS dDate,	                          --| Пустое поле (необходимо для корректной операции UNION);
			rr.nUnitId,	                          --| ID цеха;
			su.cNameUnit,	                          --| Название цеха;
			rr.nEquipmentId,                          --| ID оборудования (печи);
			eq.cNameEquipment,                        --| Название печи;
			dmm.nMaterialId   AS nParentMaterialId,   --| ID корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
			dmm.cNameMaterial AS cNameParentMaterial, --| Название корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
			NULL AS nMaterialOrParentMaterialId,
			--| ID материала;
			nMaterialId = CASE WHEN (rr.nIsRemelting = 0) THEN dm.nMaterialId ELSE -dm.nMaterialId END,
			--| Название материала;
			cNameMaterial = CASE WHEN (rr.nIsRemelting = 0) THEN dm.cNameMaterial ELSE 'Переплав' END,
			NULL AS nMarkId,	  --| Пустое поле (необходимо для корректной операции UNION);
			NULL AS cNameMark,	  --| Пустое поле (необходимо для корректной операции UNION);
			rr.nValuePlan,		  --| План производства (сутки);
			rr.nValue,		  --| Факт производства (сутки);
			NULL AS nValueMark,	  --| Пустое поле (необходимо для корректной операции UNION);
			rr.nValuePlanMonth,	  --| План производства с начала месяца;
			rr.nValueMonth,		  --| Факт производства с начала месяца;
			NULL AS nValueMarkMonth,  --| Пустое поле (необходимо для корректной операции UNION);
			rr.nValueEnergyPlan,	  --| План расхода электроэнергии(сутки);
			--| Факт расхода электроэнергии(сутки);
			nValueEnergy = 
				CASE WHEN (rr.nValue IS NOT NULL)  --| Выводим расход эл.эн если запись обладает фактом выпуска
					  AND (dm.nMaterialId NOT IN(235,295,307)) --| и это не шлак (235 "Шлак ФС и ФХС", 295 "Шлак ФХ", 307 "Шлак ФСМн".
					 THEN rr.nValueEnergy  
				END,
			--| План расхода электроэнергии с начала месяца;
			rr.nValueEnergyPlanMonth, 
			--| Факт расхода электроэнергии с начала месяца;
			nValueEnergyMonth = 
				CASE WHEN (rr.nValueMonth IS NOT NULL) --| Отображаем расход эл.эн если запись обладает фактом выпуска
					  AND (dm.nMaterialId NOT IN(235,295,307)) --| и это не шлак (235 "Шлак ФС и ФХС", 295 "Шлак ФХ", 307 "Шлак ФСМн".
					 THEN rr.nValueEnergyMonth  
				END,
			rr.nValueEnergyNormMin,   --| Минимальная норма эл. энергии среди сплавов выплавляемых печью;
			rr.nValueEnergyNormMax,   --| Максимальная норма эл. энергии среди сплавов выплавляемых печью;
			rr.nIsRemelting		  --| Признак переплава: 0-обычная плавка, 1-переплав;
		FROM 
		(
			SELECT 
				tt.nUnitId,	  --| ID цеха;
				tt.nEquipmentId,  --| ID оборудования (печи);
				--| ID корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
				pm.nMaterialId,
				--| Получение ID корневого материала-родителя 
				--| с принудительным указанием родителя для шлаковых выпусков. 
				--| Ввиду того, что шлак не входит в состав основного сплава(не является его потомком)-
				--| делаем его таковым т.к. для подведения итогов в файле отчёта(rdl)
				--| выпуски необходимо сгруппировать по какому-то признаку, в данном случае по "nParentMaterialId".
				nParentMaterialId =
					CASE pm.nMaterialId 
						WHEN 235 THEN 261 --| если 235(Шлак ФС и ФХС) тогда родитель 261(ФХС); 
						WHEN 295 THEN 269 --| если 295(Шлак ФХ) тогда родитель 269(ФХ); 
						WHEN 307 THEN 260 --| если 307(Шлак ФСМн) тогда родитель 260(ФСМн); 
						ELSE pm.nMaterialId 
					END,
				
				--| План производства печи за сутки;
				SUM(ISNULL(pln.nValuePlan, adv.nValuePlan)) AS nValuePlan,
				--| План производства печи с начала месяца;
				SUM(ISNULL(pln.nValuePlanMonth, adv.nValuePlanMonth)) AS nValuePlanMonth,
				app.nValue,		   --| Факт производства печи за сутки;
				app.nValueEnergyPlan,	   --| План расхода электроэнергии печью за сутки;
				app.nValueEnergyNormMin,   --| Минимальная норма эл. энергии среди сплавов выплавляемых печью;
				app.nValueEnergyNormMax,   --| Максимальная норма эл. энергии среди сплавов выплавляемых печью;
				app.nValueMonth,	   --| Факт производства печи с начала месяца;
				app.nValueEnergyPlanMonth, --| План расхода электроэнергии печью с начала месяца;
				ea.nValueEnergy,	   --| Факт расхода электроэнергии печью за сутки;
				ea.nValueEnergyMonth,	   --| Факт расхода электроэнергии печью с начала месяца;
				tt.nIsRemelting		   --| Признак переплава: 0-обычная плавка, 1-переплав;
			FROM
			(
				SELECT nUnitId, nEquipmentId, nMaterialOrParentMaterialId as nMaterialId, nIsRemelting
				FROM #tData_2
				GROUP BY nUnitId, nEquipmentId, nMaterialOrParentMaterialId, nIsRemelting
				
			) AS tt
			
			--| Получение суммарного объёма производства текущей печи за сутки и с начала месяца(факт) +
			--| расчёт суммарного расхода электроэнергии за сутки и с начала месяца(план).
			OUTER APPLY
				( 
					SELECT  
						MIN(td.nMaterialOrParentMaterialId) AS nMaterialId, --| MIN чтобы в группировку не включать.
						MIN(dm.nMaterialTypeId) AS nMaterialTypeId,	    --| Тип материала (MIN чтобы в группировку не включать).
						--| Получение фактического суммарного объёма производства печи за сутки;
						nValue =		SUM(CASE WHEN(td.dDate BETWEEN @dDateBegin AND @dDateEnd) THEN nValue ELSE NULL END),
						--| Получение планового расхода эл. энергии по печи за сутки;
						nValueEnergyPlan =	SUM(CASE WHEN(td.dDate BETWEEN @dDateBegin AND @dDateEnd) THEN td.nValue * td.nValueEnergyNormMin / 1000.0 ELSE NULL END),
						--| Получение минимальной нормы эл. энергии среди сплавов выплавляемых печью;
						nValueEnergyNormMin =	MIN(CASE WHEN(td.dDate BETWEEN @dDateBeginMonth AND @dDateEnd) THEN td.nValueEnergyNormMin ELSE NULL END),
						--| Получение максимальной нормы эл. энергии среди сплавов выплавляемых печью;
						nValueEnergyNormMax =	MAX(CASE WHEN(td.dDate BETWEEN @dDateBeginMonth AND @dDateEnd) THEN td.nValueEnergyNormMin ELSE NULL END),
						--| Получение фактического суммарного объёма производства печи с начала месяца;
						nValueMonth =		SUM(CASE WHEN(td.dDate BETWEEN @dDateBeginMonth AND @dDateEnd) THEN nValue ELSE NULL END),
						--| Получение планового расхода эл. энергии по печи с начала месяца.
						nValueEnergyPlanMonth = SUM(CASE WHEN(td.dDate BETWEEN @dDateBeginMonth AND @dDateEnd) THEN (td.nValue * td.nValueEnergyNormMin / 1000.0) ELSE NULL END)
					FROM #tData_2 AS td
					LEFT JOIN dctMaterial  AS dm ON dm.nMaterialId = td.nMaterialOrParentMaterialId
					WHERE (td.nUnitId = tt.nUnitId) 
					  AND (td.nEquipmentId = tt.nEquipmentId)
					  AND (td.nIsRemelting = tt.nIsRemelting)					  
					GROUP BY td.nUnitId, td.nEquipmentId, td.nMaterialId
				) AS app
				
			--| Получение ID корневого материала-родителя;
			CROSS APPLY( SELECT dbo.GetTopParentMaterialId(app.nMaterialId) AS nMaterialId ) AS pm
			
			--| Получение плана производства печи за сутки и с начала месяца.
			OUTER APPLY
				(
					SELECT 
						pln.nMaterialId,
						--| План производства печи за сутки;
						nValuePlan = 
							SUM(CASE WHEN (pln.dDatePlan >= @dDateBegin) 
									 AND (dm.nMaterialTypeId = ap4.nMaterialTypeId)
									 THEN ISNULL(pln.nValuePlanChrome, pln.nValuePlan)
									 ELSE NULL 
								END),
						--| План производства печи с начала месяца;
						nValuePlanMonth = 
							SUM(CASE WHEN (pln.dDatePlan >= @dDateBeginMonth) 
									  AND (dm.nMaterialTypeId = ap4.nMaterialTypeId)
									 THEN ISNULL(pln.nValuePlanChrome, pln.nValuePlan) 
									 ELSE NULL 
								END)
					FROM dbo.PlanProductionUnitDay  AS pln --| Таблица сменно-суточных планов производства ФСП.
					LEFT JOIN dctMaterial  AS dm ON dm.nMaterialId = pln.nMaterialId,
						--| Заводим внешнее значение в запрос т.к. в статических функциях (SUM) 
						--| использовать внешние ссылки нельзя.
					(SELECT app.nMaterialTypeId) AS ap4
					WHERE (pln.nUnitId = tt.nUnitId) 
					  AND (pln.nEquipmentId = tt.nEquipmentId) 
					  AND (pln.nMaterialId  = tt.nMaterialId)
					  AND (pln.nIsRemelting = tt.nIsRemelting)
					  AND (pln.dDatePlan BETWEEN @dDateBeginMonth AND @dDateEnd)
					GROUP BY pln.nMaterialId
				) AS pln
			
			--| Дополнительное получение плана производства печи как суммы планов выпуска марок данной печью.
			--| К примеру, для ФХС план производства на печь указывается не на сплав-родитель, а на марки
			--| ФХС40 и ФХС48 соответственно, для получения общего плана по родительскому сплаву 
			--| необходимо выполнить сложение планов ФХС40 и ФХС48.
			OUTER APPLY 
				( SELECT 
					SUM(tdd.nValuePlan)	 AS nValuePlan,	    --| План производства печи за сутки;
					SUM(tdd.nValuePlanMonth) AS nValuePlanMonth --| План производства печи с начала месяца.
				  FROM 
					(
						SELECT 
							SUM(CASE WHEN (dDate BETWEEN @dDateBegin AND @dDateEnd) THEN nValuePlan END) AS nValuePlan, 
							SUM(CASE WHEN (dDate BETWEEN @dDateBeginMonth AND @dDateEnd) THEN nValuePlan END) AS nValuePlanMonth
						FROM #tData_2 AS td
						WHERE (nEquipmentId = tt.nEquipmentId) 
						  AND (nParentMaterialId = tt.nMaterialId)
						  AND (nIsRemelting = tt.nEquipmentId)
					) AS tdd
				) AS adv									  	
			
			--| Ред.: Пантелеев М.Ю. 
			--| Дата: 14.09.2015г.
			--| Получение суммарного расхода эл.энергии печью - за сутки и с начала месяца.
			--| Расход эл. энергии получаем и на РВ, и на основной сплав (зависит от "tt.nIsRemelting").
			OUTER APPLY 
				(
					SELECT 
						--| Cуммарный расход эл.энергии печью за сутки.
						nValueEnergy = SUM(CASE WHEN (mea.dDate BETWEEN @dDateBeginIn AND @dDateEndIn) THEN nValueActive ELSE NULL END), --- eap.nValueEnergyRemelting,
						--| Cуммарный расход эл.энергии печью с начала месяца.
						nValueEnergyMonth = SUM(CASE WHEN (mea.dDate BETWEEN @dDateBeginMonth_UTC AND @dDateEndIn) THEN nValueActive ELSE NULL END) --- eap.nValueEnergyRemeltingMonth
					FROM dbo.mcEnergyAccount AS mea --| Таблица расхода электроэнергии(наполняется 
									--| автоматически данными из БД цехов во время синх-ции).
					--| Подключаем записи переплавов в период выпуска которых,
					--| входят записи из табл. расхода эл.эн.
					LEFT JOIN #tData_1 AS td1 ON
					  --| ID цеха из табл. расхода эл.эн. = ID цеха искомой записи о переплаве.
						  (td1.nUnitId = mea.nUnitId)
					  --| ID печи из табл. расхода эл.эн. = ID печи искомой записи о переплаве.	
					  AND (td1.nEquipmentId = mea.nEquipmentId)
					  --| Искомая запись является переплавом. 
					  AND (td1.nIsRemelting = 1)
					  --| Дата записи из табл. расхода эл.эн. 
					  --| входит в интервал начала-окончания искомой записи о переплаве.
					  AND (td1.nIsRemelting = 1 AND mea.dDate BETWEEN td1.dDateBegin AND td1.dDateEnd)
					WHERE 
					  --| Искомая запись (из табл. эл.энергии) имеет ID цеха = ID цеха 
					  --| текущей записи из внешней выборки (см. "tt");
					      (mea.nUnitId = tt.nUnitId)
					  --| Искомая запись (из табл. эл.энергии) имеет ID печи = ID печи 
					  --| текущей записи из внешней выборки (см. "tt");
					  AND (mea.nEquipmentId = tt.nEquipmentId)
					  --| Активная мощность не может быть больше 100 МВт⋅ч,
					  --| подобные записи ошибочны, они не берутся;
					  AND (mea.nValueActive < 100)
					  --| Дата искомой записи (из табл. эл.энергии) входит в интервал
					  --| с начала месяца по заданную дату;
					  AND (mea.dDate BETWEEN @dDateBeginMonth_UTC AND @dDateEndIn)
					  --| ГЛАВНОЕ УСЛОВИЕ текущей выборки(ради него, добавлен LEFT JOIN выше). 
					  --| Согласно условию ниже, осуществляется расчёт 
					  --| расхода эл.энергии либо на переплав, либо на обычную выплавку 
					  --| (до этого была проблема: к примеру, из 500 МВт⋅ч на печь затрачивалось  
					  --| 200 МВт⋅ч на переплав и на основной сплав выводилось 500, 
					  --| сейчас, 200 на переплав и 300 на основную выплавку, из общих 500).
					  AND (ISNULL(td1.nIsRemelting, 0) = tt.nIsRemelting)
				) AS ea
				
			WHERE (tt.nUnitId IS NOT NULL)
			GROUP BY 
				tt.nUnitId, tt.nEquipmentId, pm.nMaterialId, app.nValue, app.nValueEnergyPlan, 
				app.nValueEnergyNormMin, app.nValueEnergyNormMax, app.nValueMonth, 
				app.nValueEnergyPlanMonth, ea.nValueEnergy, ea.nValueEnergyMonth, tt.nIsRemelting
				
		) AS rr
		
		--| Получение названия печи.
		OUTER APPLY(SELECT cNameEquipment FROM dbo.Equipments WHERE nEquipmentId = rr.nEquipmentId) AS eq
		--| Получение названия цеха.
		OUTER APPLY(SELECT cNameUnit FROM dbo.stUnit  WHERE nUnitId = rr.nUnitId) AS su
		--| Получение ID и названия корневого материала-родителя (ФХ,ФСМн,ФХС,ФС);
		OUTER APPLY(SELECT nMaterialId, cNameMaterial FROM dbo.dctMaterial  WHERE nMaterialId = rr.nMaterialId) AS dm
		--| Получение ID и названия общего материала-родителя для марок и шлаковых выпусков.
		OUTER APPLY(SELECT nMaterialId, cNameMaterial FROM dbo.dctMaterial  WHERE nMaterialId = rr.nParentMaterialId) AS dmm
		
		ORDER BY nUnitId, nEquipmentId		
END
GO
