--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('GetHeapWeightAndAvgChemAnalysis') IS NOT NULL
	DROP PROCEDURE dbo.GetHeapWeightAndAvgChemAnalysis
GO
-->*********************************************************************************************<--
--> Процедура осуществляет расчёт веса и средневзвешенного хим. анализа террикона.
--> 
--> Входные параметры:
-->  - @nHeapIdIn		--| Идентификатор террикона.
-->
--> Выходные параметры:
-->  - @nHeapWeightOUT		--| Масса террикона рассчитанная исходя из выполненных движений.
-->  - @xHeapValueProbeOUT	--| Хим. анализ террикона рассчитанный исходя из движений (предназначен для записи в "macHeap").
-->  - @nSumWeightI_OUT		--| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
-->  - @nSumWeightO_OUT		--| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
-->  - @dDateEventOUT		--| Дата последней операции "Зачистки" либо "Замера" террикона. 
-->  - @dLastEditOUT		--| Дата последнего движения.
-->  
--> Автор: Пантелеев М.Ю.
--> Дата:  20.01.2015г.
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.GetHeapWeightAndAvgChemAnalysis
( 
	--| Входные параметры:
	@nHeapIdIn	    INT		  = NULL,        --| Идентификатор террикона.

	--| Выходные параметры:	
	@nHeapWeightOUT	    DECIMAL(9,3)  = NULL OUTPUT, --| Масса террикона рассчитанная исходя из выполненных движений.
	@xHeapValueProbeOUT NVARCHAR(MAX) = NULL OUTPUT, --| Хим. анализ террикона рассчитанный исходя из движений (предназначен для записи в "macHeap").
	@nSumWeightI_OUT    DECIMAL(9,3)  = 0	 OUTPUT, --| Суммарная масса пополнений террикона исходя из выполненных по нему движений.
	@nSumWeightO_OUT    DECIMAL(9,3)  = 0	 OUTPUT, --| Суммарная масса изъятий террикона исходя из выполненных по нему движений.
	@dDateEventOUT	    DATETIME ='19170711' OUTPUT, --| Дата последней операции "Зачистки" либо "Замера" террикона. 
	@dLastEditOUT	    DATETIME ='19170711' OUTPUT  --| Дата последнего движения.
)
AS
BEGIN TRY
	IF @nHeapIdIn IS NOT NULL --| Если ID террикона передан.
	BEGIN
		--| Удаление временной таблицы #tData_4, если по каким-либо причинам 
		--| она не была удалена после предыдущего запуска ХП.
		IF OBJECT_ID(N'tempdb..#tData_4', N'U') IS NOT NULL 
			DROP TABLE #tData_4	
		
		--| Создание временной таблицы #tData_4. 
		--| Таблица предназначена для временного хранения информации о движениях террикона.
		CREATE TABLE #tData_4  
		(		
			nRowNumber	INT,	      --| Порядковый номер строки (необходимо для работы цикла, см. ниже).	 
			nWeight		DECIMAL(9,3), --| Вес движения.
			xValueProbe	XML,	      --| Хим. анализ движения.
			nIsWeightIn	BIT,	      --| Статус типа движения:
						      --|	0 – изъятие
						      --|	1 - пополнение
			dDateEvent	DATETIME,     --| Дата движения. 
			dDateEventFirst DATETIME      --| Дата последней операции "Зачистки" либо "Замера" террикона.
						      --| С этой даты начинается выборка движений террикона.
		)
	
		INSERT INTO	#tData_4
		SELECT  
			ROW_NUMBER() OVER (ORDER BY ISNULL(dt2.dDateEvent,1)) AS nRowNumber, --| Порядковый номер строки.
			dt2.nWeight,	  --| Вес движения.
			dt2.xValueProbe,  --| Хим. анализ движения.
			dt2.nIsWeightIn,  --| Статус типа движения.
					  --|	0 – изъятие
					  --|	1 - пополнение
			dt2.dDateEvent,	  --| Дата движения. 
			dt1.dDateEvent AS dDateEventFirst --| Дата последней операции "Зачистки" либо "Замера" террикона.
							  --| С этой даты начинается выборка движений террикона.
		FROM dbo.macHeap ms
		--| Получение даты последней "Зачистки" либо "Замера" террикона.
		--| Операция "Замер" - ручная корректировка массы террикона сотрудниками УАИС 
		--| на основании запроса цеха (средствами SSMS).
		OUTER APPLY(
				SELECT TOP(1) dbo.GetDtForTimeZone(msh.dDateEvent) AS dDateEvent
				FROM dbo.macHeapHistory msh
				WHERE (msh.cNote like 'Зачистка хранилища' OR msh.cNote like 'Замер')
				  AND msh.nHeapId = ms.nHeapId
				  AND msh.nHeapOperationId IS NULL 
				ORDER BY msh.dDateEvent DESC
			    ) dt1 
		--| Получение информации о движениях террикона.
		OUTER APPLY(
				SELECT 							
					so.dDateOperation AS dDateEvent, --| Дата движения.
					msh.nWeight,			 --| Вес движения.
					ISNULL(so.xValueProbe,msh.xValueProbe) AS xValueProbe, --| Хим. анализ движения.
					CASE 
						WHEN(so.nWeightFactor = 1 AND so.nIsExecuted = 1) then  1 --| Пополнение.
						WHEN(so.nWeightFactor =-1 AND so.nIsExecuted = 1) then  0 --| Изъятие.
					END AS nIsWeightIn --| Статус типа движения.
				FROM dbo.macHeapOperation so 
				LEFT JOIN dbo.macHeapHistory msh ON so.nHeapOperationId = msh.nHeapOperationId
				WHERE so.nHeapId = ms.nHeapId
				 
				 --| Выбираются только те движения, дата создания которых, больше даты "Зачистки" либо "Замера".
				 --| Если у террикона отсутствуют операции "Зачистки" или "Замера" выборка движений 
				 --| осуществляется начиная с даты создания террикона.
				 AND  so.dDateOperation >= ISNULL(dt1.dDateEvent, ms.dDateCreate)
				 
				 --| Выбираются лишь обработанные движения имеющие тип пополнение либо изъятие.
				 --| (необработанные – без веса или хим. состава, исключаются)
				 AND (
					   (so.nWeightFactor = 1 AND so.nIsExecuted = 1) OR --| Пополнение.
					   (so.nWeightFactor =-1 AND so.nIsExecuted = 1)    --| Изъятие.
					 ) 
				UNION ALL 
				
				SELECT 
					dbo.GetDtForTimeZone(msh.dDateEvent) AS dDateEvent, --| Дата движения.
					msh.nWeight,	 --| Вес движения.
					msh.xValueProbe, --| Хим. анализ движения.
					1 AS nIsWeightIn --| Статус типа движения:
							 --|	0 – изъятие
							 --|	1 - пополнение
				FROM dbo.macHeapHistory msh
				WHERE (msh.cNote like 'Замер' OR msh.cNote like 'Пополнение хранилища')
				  AND msh.nHeapId = ms.nHeapId
				  AND msh.nHeapOperationId IS NULL
				  
				  --| Выбираются только те движения, дата создания которых, больше даты "Зачистки" либо "Замера".
				  --| Если у террикона отсутствуют операции "Зачистки" или "Замера" выборка движений 
				  --| осуществляется начиная с даты создания террикона.
				  AND dbo.GetDtForTimeZone(msh.dDateEvent) >= ISNULL(dt1.dDateEvent, ms.dDateCreate)
			     ) dt2
		WHERE ms.nHeapId = @nHeapIdIn 
	 	
	 	--| У движений террикона обязательно должны быть:
	 	AND (ISNULL(dt2.nWeight,0) > 0)					   --| 1) вес (полож. значение);
		AND (LEN(ISNULL(CONVERT(NVARCHAR(MAX), dt2.xValueProbe),'')) > 30) --| 2) хим. анализ.
	        --SELECT * FROM #tData_4
	    			
		DECLARE 
			@nHeapWeight     DECIMAL(9,3) = NULL, --| Масса террикона.
			@xHeapValueProbe XML	      = NULL, --| Средневзвешенный хим. анализ террикона.
			@nWeight	 DECIMAL(9,3) = NULL, --| Вес движения.
			@xValueProbe     XML	      = NULL, --| Хим. анализ движения.
			@nIsWeightIn     BIT	      = NULL, --| Статус типа движения.
						  	      --|	0 – изъятие
							      --|	1 - пополнение
			@nTotalWeight    DECIMAL(9,3) = NULL, --| Масса террикона + вес движения.
			@rX		 dbo.IdFloat2RowTable,--| Средневзвешенный хим. анализ террикона.
			@nRowNumber      INT, --| Порядковый номер строки (необходимо для работы цикла, см. ниже).	
			@nCount          INT, --| Количество итераций цикла = количеству движений террикона.
			@nRowCount       INT  --| Счётчик итераций цикла, инкрементируется от 0 до @nCount.
		
		
		 --| Подготовка к циклу.
		SELECT
			@nCount = (SELECT COUNT(nRowNumber) FROM #tData_4), --| Получение кол-ва итераций цикла. 
			@nRowCount = 0,	      --| Обнуление счётчика цикла.
			@nSumWeightI_OUT = 0, --| Обнуление счётчика суммы пополнений.
			@nSumWeightO_OUT = 0, --| Обнуление счётчика изъятий.
			
			--| Получение даты последней операции "Зачистки" или "Замера" террикона 
			--| (в табл. #tData_4 она для всех строк одинакова).
			@dDateEventOUT = ISNULL((SELECT TOP(1) dDateEventFirst FROM #tData_4),'19170711'),
			
			--| Получение даты последнего движения.
			@dLastEditOUT = ISNULL((SELECT MAX(dlastEdit) FROM dbo.macHeapHistory WHERE nHeapId = @nHeapIdIn),'19170711')
			
		--SELECT 'До цикла всё - OK.'	
		
		
		--| Цикл по движениям террикона.
		--| Рассчитываются:
		--|		- средневзвешенный хим. анализ террикона;
		--|		- масса террикона;
		--|		- масса пополнений;
		--|		- масса изъятий.
		WHILE (SELECT TOP(1)1 FROM #tData_4) IS NOT NULL
		AND @nRowCount < @nCount 
		BEGIN --*

			SELECT TOP(1)
				@nRowNumber  = nRowNumber,
				@nWeight	 = nWeight,
				@xValueProbe = xValueProbe,
				@nIsWeightIn = nIsWeightIn
			FROM #tData_4 
			ORDER BY dDateEvent ASC
				
			IF (@nIsWeightIn = 1) --| Если пополнение.
			BEGIN
				--| Масса террикона + вес движения.
				SET @nTotalWeight = ISNULL(@nHeapWeight,0)+ISNULL(@nWeight,0)
				
				--| Хим. анализ террикона. 
				INSERT INTO @rX
				SELECT 
					t.c.query('./nParametrId').value('.','int') AS nParametrId,
					t.c.query('./cValueParametr').value('.','FLOAT')* @nHeapWeight AS nValueParametr
				FROM @xHeapValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
				WHERE NULLIF(t.c.query('./cValueParametr').value('.','varchar(300)'),'') IS NOT NULL
				
				--| Хим. анализ движения. 
				;WITH cte AS
				(
					SELECT 
					t.c.query('./nParametrId').value('.','int') AS nParametrId,
					t.c.query('./cValueParametr').value('.','FLOAT') AS nValueParametr
					FROM @xValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
					WHERE NULLIF(t.c.query('./cValueParametr').value('.','varchar(300)'),'') IS NOT NULL
				)
				
				--| Расчёт средневзвешенного хим. анализа.
				MERGE @rX AS R
				USING cte AS x
				ON (r.nId = x.nParametrId)
				WHEN MATCHED THEN 
					UPDATE SET nVal = r.nVal + x.nValueParametr * @nWeight
				WHEN NOT MATCHED THEN
					INSERT (nId,nVal)
					VALUES (x.nParametrId,x.nValueParametr * @nWeight);
				
				------------------------------------------------------------------------
				IF @nTotalWeight > 0
				BEGIN
								
				UPDATE @rX SET nVal = nVal / @nTotalWeight
				SET @xHeapValueProbe = dbo.GetProbeXMLbyTable(@rX)
			
				END
				------------------------------------------------------------------------
				--| Расчёт массы террикона и суммарной массы пополнений.
				SELECT 
					@nHeapWeight = ISNULL(@nHeapWeight,0) + @nWeight,
					@nSumWeightI_OUT = @nSumWeightI_OUT + ABS(ISNULL(@nWeight,0))

			END

			IF (@nIsWeightIn = 0) --| Если изъятие.
			BEGIN
				--| Расчёт массы террикона и суммарной массы изъятий.
				SELECT 
					@nHeapWeight = ISNULL(@nHeapWeight,0) - @nWeight,
					@nSumWeightO_OUT = @nSumWeightO_OUT + ABS(ISNULL(@nWeight,0))
			END
			
			--| Удаление обработанного движения из временной таблицы.
			DELETE FROM #tData_4 
			WHERE nRowNumber  = @nRowNumber
			
			--| Инкремент счётчика.
			SET @nRowCount = @nRowCount + 1
			
			--SELECT @nRowCount, @dDateEvent, @nWeight, @xValueProbe, @nIsWeightIn,@nHeapWeight, dbo.GetProbeXMLtoStr(@xHeapValueProbe,';')
			
			--| Обнуление промежуточных значений, для корректных расчётов со следующим движением.
			SELECT
			   @nWeight		 = 0,
			   @xValueProbe  = NULL,
			   @nIsWeightIn  = NULL,
			   @nTotalWeight = 0
			DELETE FROM @rX
		
		END --* Конец цикла.

		
		
		DECLARE @nMaterialId	 INT, --| ID материала, необходим для получения ID типа материала.
			@nMaterialTypeId INT  --| ID типа материала, необходим для сортировки хим. анализа террикона,
					      --| согласно порядка следования хим. компонентов (см. ниже).
		
		--| Получение ID материала террикона.
		SET	@nMaterialId = (SELECT TOP(1)nMaterialId FROM dbo.macHeap WHERE nHeapId = @nHeapIdIn)	
		--| Получение ID типа материала террикона.
		SET @nMaterialTypeId = (SELECT t.nMaterialTypeId 
					FROM dbo.dctMaterial t 
					WHERE t.nMaterialId = dbo.GetFirstMatParent(@nMaterialId))	
		
		--| Формирование выходных параметров.
		SELECT 
			@nHeapWeightOUT  = ISNULL(@nHeapWeight,0),
			@nSumWeightI_OUT = ISNULL(@nSumWeightI_OUT,0),
			@nSumWeightO_OUT = ISNULL(@nSumWeightO_OUT,0),
			@dDateEventOUT	 = ISNULL(@dDateEventOUT,'19170711'),
			@dLastEditOUT    = ISNULL(@dLastEditOUT,'19170711'),
			
			--| Получение отсортированного хим. анализа террикона:
			--| 1 извлечение хим. анализа из XML в таблицу,
			--| 2 сортировка хим. компонентов.
			--| 3 преобразование из таблицы в строковую переменную со структурой XML.
			@xHeapValueProbeOUT = 
				CONVERT(NVARCHAR(MAX), ISNULL(
								   (SELECT 
									t.c.query('./nParametrId').value('.','INT') AS nParametrId,
									mp.cNameParametr,
									CONVERT( DECIMAL(9,3), t.c.query('./cValueParametr').value('.','FLOAT')) AS cValueParametr
								    FROM @xHeapValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
								    INNER JOIN dbo.dctMatParam	   AS mp  ON mp.nParametrId = t.c.query('./nParametrId').value('.','INT')
								    LEFT  JOIN dbo.dctMatParamLink AS mpl ON (mpl.nParametrId = mp.nParametrId) AND (mpl.nMaterialTypeId = @nMaterialTypeId)
								    WHERE NULLIF(t.c.query('./cValueParametr').value('.','NVARCHAR(300)'),'') IS NOT NULL
								    ORDER BY ISNULL(mpl.nSequence, 1024)
								    FOR XML PATH(N'cResultProbe'), ROOT(N'ProbeParameters'))
								,''))
										  
		--SELECT 
		--	@nHeapWeight, 
		--	dbo.GetProbeXMLtoStr(@xHeapValueProbe,';'),
		--	@nSumWeightI_OUT,
		--	@nSumWeightO_OUT,
		--	@dDateEventOUT,
		--	@dLastEditOUT	
	END
	
	--| Удаление временной таблицы #tData_4.
	IF OBJECT_ID(N'tempdb..#tData_4', N'U') IS NOT NULL 
		DROP TABLE #tData_4	
	
END TRY
BEGIN CATCH
		
	IF OBJECT_ID(N'tempdb..#tData_4', N'U') IS NOT NULL 
		DROP TABLE #tData_4	
	
	DECLARE @cUserErrMessage NVARCHAR(200) = 
			Char(10) + 'Ошибка в процедуре "GetHeapWeightAndAvgChemAnalysis" (см.:' + @@servername + '\' + DB_NAME() + '). '
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
END CATCH							
GO

