--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('GetWeightAndChemAnalysisHeapUnion') IS NOT NULL
	DROP PROCEDURE dbo.GetWeightAndChemAnalysisHeapUnion
GO
-->*********************************************************************************************<--
--> Процедура осуществляет расчёт веса и средневзвешенного хим. анализа результирующего террикона,  
--> террикона образованного в результате объединения.
--> 
--> Входные параметры:
-->  - @cHeapListIn	    --| Таблица GUID'ов терриконов участвующих в объединении.
-->  - @nMaterialIdIn	    --| ID материала террикона - результата объединения.
-->
--> Выходные параметры:
-->  - @nHeapWeightOUT	    --| Масса террикона - результата объединения, рассчитанная исходя 
--> 			    --| из масс входных терриконов.
-->  - @xHeapValueProbeOUT  --| Хим. анализ террикона рассчитанный исходя из хим. анализов 
--> 			    --| входных терриконов.
-->  
--> Автор: Пантелеев М.Ю.
--> Дата:  28.05.2015г.
-->*********************************************************************************************<--
CREATE PROCEDURE dbo.GetWeightAndChemAnalysisHeapUnion
( 
	--| Входные параметры:
	@cHeapListIn		 NVARCHAR(MAX) = NULL,	      --| Список GUID'ов терриконов выбранных для объединения.
	@nMaterialIdIn		 INT = NULL,		      --| ID материала террикона - результата объединения.
	--| Выходные параметры:	
	@nHeapWeightOUT	         DECIMAL(9,3)  = NULL OUTPUT, --| Масса террикона - результата объединения.
	@xHeapValueProbeOUT      NVARCHAR(MAX) = NULL OUTPUT  --| Хим. анализ террикона - результата объединения.
)
AS
BEGIN TRY
	
	IF (@cHeapListIn != '')	 --| Если список терриконов передан.
	BEGIN --*
		
		--| Удаление временных таблиц #tData_1, #tGUIDsTable_2, если по каким-либо причинам 
		--| они не были удалены после предыдущего запуска ХП.
		IF OBJECT_ID(N'tempdb..#tGUIDsTable_2', N'U') IS NOT NULL 
			DROP TABLE #tGUIDsTable_2
		IF OBJECT_ID(N'tempdb..#tData_1', N'U') IS NOT NULL 
			DROP TABLE #tData_1	
					
		--| Создание временной таблицы #tGUIDsTable_2.
		--| Таблица предназначена для временного хранения GUID’ов объединяемых терриконов.
		CREATE TABLE #tGUIDsTable_2
		(
			nGUID UNIQUEIDENTIFIER
		)
		
		--| Наполнение временной таблицы #tGUIDsTable_2.
		--| Получение GUID'ов путём преобразования входной строки в таблицу по разделителю "," 
		--| с сохранением полученного результата в таблицу #tGUIDsTable_2.
		DECLARE @SQL NVARCHAR(MAX)
		SET @SQL = @cHeapListIn
		SET @SQL = 'SELECT '''+REPLACE(LTRIM(@SQL), ',', ''' AS nGUID UNION ALL SELECT ''')+''''
		INSERT INTO #tGUIDsTable_2
		EXEC(@SQL);
		
		--| Создание временной таблицы #tData_1. 
		--| Таблица предназначена для временного хранения масс и хим. анализа исходных терриконов.
		CREATE TABLE #tData_1  
		(		
			nRowNumber	INT,          --| Порядковый номер строки (необходимо для работы цикла, см. ниже).	 
			nWeight		DECIMAL(9,3), --| Вес исходного террикона.
			xValueProbe	XML	      --| Хим. анализ исходного террикона.
		)
		
		--| Наполнение временной таблицы #tData_1.
		INSERT INTO #tData_1
		SELECT  
			ROW_NUMBER() OVER (ORDER BY ISNULL(nHeapId,1)) AS nRowNumber, --| Порядковый номер строки.
			nWeight,     --| Вес исходного террикона.
			xValueProbe  --| Хим. анализ исходного террикона.
		FROM dbo.macHeap ms
		WHERE ms.nGUID IN (SELECT nGUID FROM #tGUIDsTable_2)
	 	 --| У исходных терриконов обязательно должны быть:
	 	 AND (ISNULL(nWeight,0) > 0)					--| 1) положительный вес;
		 AND (LEN(ISNULL(CONVERT(NVARCHAR(MAX), xValueProbe),'')) > 30) --| 2) наличие хим. анализа.
	    
	    --SELECT * FROM #tData_1
		 
		DECLARE	@nHeapWeight     DECIMAL(9,3) = NULL  --| Масса результирующего террикона.
		DECLARE	@xHeapValueProbe XML	      = NULL  --| Средневзвешенный хим. анализ результ. террикона.
		DECLARE	@nWeight	 DECIMAL(9,3) = NULL  --| Вес одного из исходных терриконов.
		DECLARE	@xValueProbe     XML	      = NULL  --| Хим. анализ одного из исходных терриконов.
		DECLARE	@nTotalWeight    DECIMAL(9,3) = NULL  --| Промежут. масса террикона + вес одного из исходных тер.
		DECLARE	@rX		 dbo.IdFloat2RowTable --| Средневзвешенный хим. анализ результирующего террикона.
		DECLARE	@nRowNumber      INT --| Порядковый номер строки (необходимо для работы цикла, см. ниже).	
		DECLARE	@nCount          INT --| Количество итераций цикла = количеству исходных терриконов.
		DECLARE	@nRowCount       INT --| Счётчик итераций цикла, инкрементируется от 0 до @nCount.
		
		
		 --| Подготовка к циклу.
		SELECT
			@nCount = (SELECT COUNT(nRowNumber) FROM #tData_1), --| Получение кол-ва итераций цикла. 
			@nRowCount = 0	   --| Обнуление счётчика цикла.
			
		--SELECT 'До цикла всё работает.'	
		
		--| Цикл по исходным терриконам.
		--| В цикле рассчитываются:
		--|	- средневзвешенный хим. анализ результирующего террикона;
		--|	- масса результирующего террикона;
		WHILE (SELECT TOP(1)1 FROM #tData_1) IS NOT NULL
		AND @nRowCount < @nCount 
		BEGIN --**

			SELECT TOP(1)
				@nRowNumber  = nRowNumber, --| Порядковый номер строки (по нему будет происходить удаление).
				@nWeight     = nWeight,	   --| Вес одного из исходных терриконов.
				@xValueProbe = xValueProbe --| Хим. анализ одного из исходных терриконов.
			FROM #tData_1 
			
				--| Промежуточная масса + масса одного из исходных терриконов.
				SET @nTotalWeight = ISNULL(@nHeapWeight,0)+ISNULL(@nWeight,0)
				
				--| Хим. анализ результирующего террикона. 
				INSERT INTO @rX
				SELECT 
					t.c.query('./nParametrId').value('.','int') AS nParametrId,
					t.c.query('./cValueParametr').value('.','FLOAT')* @nHeapWeight AS nValueParametr
				FROM @xHeapValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
				WHERE NULLIF(t.c.query('./cValueParametr').value('.','varchar(300)'),'') IS NOT NULL
				
				--| Хим. анализ одного из исходных терриконов. 
				;WITH cte AS
				(
					SELECT 
					t.c.query('./nParametrId').value('.','int')      AS nParametrId,
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
				
				--|---------------------------------------------------------------------
				--| Если промежуточная масса результирующего террикона + масса одного из исходных терриконов
				--| больше нуля - выполняется расчёт средневзвешенного хим. анализа.
				IF @nTotalWeight > 0
				BEGIN
								
				UPDATE @rX SET nVal = nVal / @nTotalWeight
				SET @xHeapValueProbe = dbo.GetProbeXMLbyParamTab(@rX)
			
				END
				--|----------------------------------------------------------------------
				--| Сумма масс.
				SELECT 
					@nHeapWeight = ISNULL(@nHeapWeight,0) + @nWeight

				--| Удаление записи обработанного исходного террикона из временной таблицы.
				DELETE FROM #tData_1 
				WHERE nRowNumber  = @nRowNumber
				
				--| Инкремент счётчика.
				SET @nRowCount = @nRowCount + 1
				
				--SELECT @nRowCount, @nWeight, @xValueProbe, @nHeapWeight, dbo.GetProbeXMLtoStr(@xHeapValueProbe,';')
				
				--| Обнуление промежуточных значений,  
				--| для корректных расчётов со следующим терриконом из списка.
				SELECT
				   @nWeight		 = 0,
				   @xValueProbe  = NULL,
				   @nTotalWeight = 0
				DELETE FROM @rX
			
			END --** Конец цикла по исходным(объединяемым) терриконам.

		DECLARE @nMaterialTypeId INT --| ID типа материала, необходим для сортировки хим. анализа террикона,
					     --| согласно порядка следования хим. компонентов (см. ниже).
		
		--| Получение ID типа материала террикона.
		SET @nMaterialTypeId = (SELECT t.nMaterialTypeId 
					FROM dbo.dictMat t 
					WHERE t.nMaterialId = dbo.GetFirstMatParent(@nMaterialIdIn))	
		
		--| Обработка выходных параметров.
		--| -------------------------------------------------------
		--| Масса террикона-результата объединения.
		SET @nHeapWeightOUT = ISNULL(@nHeapWeight,0)
		
		--| Хим. анализ террикона-результата объединения.	
		--| Сортировка хим. анализа террикона согласно порядка следования хим. компонентов:
		--| 1 извлечение хим. анализа из XML в таблицу,
		--| 2 сортировка хим. компонентов.
		--| 3 преобразование из таблицы в строковую переменную со структурой XML.
		SET	@xHeapValueProbeOUT = 
				CONVERT(NVARCHAR(MAX), ISNULL(
								   (SELECT 
										t.c.query('./nParametrId').value('.','INT') AS nParametrId,
										mp.cNameParametr,
										CONVERT( DECIMAL(9,3), t.c.query('./cValueParametr').value('.','FLOAT')) AS cValueParametr
									FROM @xHeapValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
									INNER JOIN dbo.dctMatParam     AS mp  ON mp.nParametrId = t.c.query('./nParametrId').value('.','INT')
									LEFT  JOIN dbo.dctMatParamLink AS mpl ON (mpl.nParametrId = mp.nParametrId) AND (mpl.nMaterialTypeId = @nMaterialTypeId)
									WHERE NULLIF(t.c.query('./cValueParametr').value('.','NVARCHAR(300)'),'') IS NOT NULL
									ORDER BY ISNULL(mpl.nSequence, 1024)
									FOR XML PATH(N'cResultProbe'), ROOT(N'ProbeParameters'))
									,''))
										  
		--SELECT 
		--	@nHeapWeight, 
		--	dbo.GetProbeXMLtoStr(@xHeapValueProbe,';'),
	
	END --*
	
	--| Удаление временных таблиц #tData_1, #tGUIDsTable_2.
	IF OBJECT_ID(N'tempdb..#tData_1', N'U') IS NOT NULL 
		DROP TABLE #tData_1	
	IF OBJECT_ID(N'tempdb..#tGUIDsTable_2', N'U') IS NOT NULL 
			DROP TABLE #tGUIDsTable_2
	
END TRY
BEGIN CATCH

	--| Удаление временных таблиц #tData_1, #tGUIDsTable_2.
	IF OBJECT_ID(N'tempdb..#tData_1', N'U') IS NOT NULL 
		DROP TABLE #tData_1	
	IF OBJECT_ID(N'tempdb..#tGUIDsTable_2', N'U') IS NOT NULL 
			DROP TABLE #tGUIDsTable_2
	
	DECLARE @cUserErrMessage NVARCHAR(200) = Char(10) + 'Ошибка в процедуре "GetWeightAndChemAnalysisHeapUnion" (сервер.:"' + @@servername + '", БД:"' + DB_NAME() + '"). ' + char(10)
	
	--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
	EXEC dbo.int_Error_Return @cUserErrMessage 
	--> Процедура логирование ошибок
	EXEC dbo.Log_Error @cUserErrMessage
	RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
		
END CATCH							
GO

