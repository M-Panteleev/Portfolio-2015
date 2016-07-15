--| Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

IF OBJECT_ID('AlterSequenceValueProbeHeapOperation') IS NOT NULL
	DROP PROCEDURE dbo.AlterSequenceValueProbeHeapOperation
GO
-->**************************************************************************************************<--
--> Процедура выполняет cортировку хим. состава операций террикона в соответсвии с 
--> порядком следования хим компонентов.
-->
--> Входные параметры:
-->  - @nHeapIdIn	  --| Идентификатор террикона.
-->  - @dDateBeginIn      --| Дата начала выборки движений террикона.
-->
--> Выходные параметры:
-->  - @nRowCountModifOut --| Количество движений террикона с отсортированным хим. анализом (в результ. выполн. ХП).
-->	
-->	Автор: Пантелеев М.Ю.
-->	Дата:  10.12.2014г.
-->**************************************************************************************************<--

CREATE PROCEDURE dbo.AlterSequenceValueProbeHeapOperation
(
	--| Входные параметры:
	@nHeapIdIn	   INT	    = NULL, --| Идентификатор террикона.
	@dDateBeginIn	   DATETIME = NULL, --| Дата движения, с которого необходимо начать проверку.
	
	--| Выходные параметры:
	@nRowCountModifOut INT OUTPUT	    --| Количество движений террикона с отсортированным хим. анализом.
) 

AS
BEGIN TRY
	IF @nHeapIdIn IS NOT NULL --| Если ID террикона передан.
	BEGIN
		--| Если входная дата начала выборки не передана, 
		--| проверка движений террикона будет выполнена за всё время.
		IF (@dDateBeginIn IS NULL) SET @dDateBeginIn = '19170711'	
		
		--| Удаление временной таблицы #tData_3, если по каким-либо причинам 
		--| она не была удалена после предыдущего запуска ХП.
		IF OBJECT_ID(N'tempdb..#tData_3', N'U') IS NOT NULL 
			DROP TABLE #tData_3	

		--| Создание временной таблицы #tData_3. 
		--| Таблица предназначена для временного хранения информации о движениях террикона.
		CREATE TABLE #tData_3
		(		
			nHeapId		 INT, --| Идентификатор террикона.
			nHeapOperationId INT, --| Идентификатор движения.
			nIsHst		 BIT, --| Признак таблицы-источника в которой храниться запись движения:
					      --|	0 - "macHeapOperation";
					      --|	1 - "macHeapHistory".
			nIsSort		 BIT, --| Признак сортировки:
					      --|	0 - хим. анализ движения корректен – сортировка не выполнялась;
					      --|	1 - порядок следования хим. компонентов не корректен - 
					      --|		выполнена сортировка. 
			xValueProbeSort	 XML  --| Хим. анализ движения после сортировки хим. компонентов (корректный вид).
		)

		--| Наполнение таблицы #tData_3.
		INSERT INTO #tData_3
		SELECT   
			so.nHeapId,	     --| Идентификатор террикона.
			so.nHeapOperationId, --| Идентификатор движения.
			so.nIsHst,	     --| Признак таблицы-источника в которой храниться запись движения.
			CASE 
				WHEN CONVERT(NVARCHAR(MAX),so.xValueProbe) != vp.xValueProbeSort THEN 1 ELSE 0
			END AS nIsSort,	     --| Признак сортировки:
					     --|	0 - хим. анализ движения корректен – сортировка не выполнялась
					     --|	1 - порядок следования хим. компонентов не корректен - 
					     --|	выполнена сортировка. 
			
			CONVERT(XML,vp.xValueProbeSort) AS xValueProbeSort --| Хим. анализ движения после  
									   --| сортировки хим. компонентов (корректный вид).
		FROM (
				--| Получение информации о движениях из таблицы "macHeapOperation".
				SELECT
					so.nHeapId,
					so.nHeapOperationId,
					msh.nInterunitId,
					ISNULL(so.xValueProbe,msh.xValueProbe)  AS xValueProbe,
					0 AS nIsHst
				FROM dbo.macHeapOperation so 
				LEFT JOIN dbo.macHeapHistory msh ON so.nHeapOperationId = msh.nHeapOperationId
				WHERE so.nHeapId = @nHeapIdIn
				AND so.dDateOperation >= @dDateBeginIn
				
				UNION ALL
				
				--| Получение информации о движениях из таблицы "macHeapHistory".
				SELECT 
					msh.nHeapId,
					msh.nHeapHistoryId as nHeapOperationId,
					msh.nInterunitId,
					msh.xValueProbe,
					1 AS nIsHst
				FROM dbo.macHeapHistory msh
				WHERE msh.nHeapId = @nHeapIdIn
					AND msh.nHeapOperationId IS NULL
					AND dbo.GetDtForTimeZone(msh.dDateEvent) >= @dDateBeginIn 
			  ) so
		LEFT JOIN dbo.Interunit ri ON ri.nInterunitId = so.nInterunitId
		LEFT JOIN dbo.TaskInterunit ti ON ti.nTaskInterunitId = ri.nTaskInterunitId			
		--| Получение Id типа материала.
		OUTER APPLY (SELECT 
					CASE 
					WHEN ti.nMaterialId IS NOT NULL THEN
					(
						SELECT t.nMaterialTypeId 
						FROM dbo.dctMaterial t 
						WHERE t.nMaterialId = ti.nMaterialId
					)
					ELSE
					(
						SELECT t.nMaterialTypeId 
						FROM dbo.dctMaterial t 
						WHERE t.nMaterialId = (SELECT nMaterialId FROM dbo.macHeap WHERE nHeapId = @nHeapIdIn )
					)
					END AS nMaterialTypeId
			      ) AS dm

		--| Получение отсортированного хим. анализа террикона:
		--| 1 извлечение хим. анализа из XML в таблицу,
		--| 2 сортировка хим. компонентов.
		--| 3 преобразование из таблицы обратно в XML.
		OUTER APPLY(SELECT
				(
					SELECT 
						t.c.query('./nParametrId').value('.','varchar(300)') AS nParametrId,
						t.c.query('./cNameParametr').value('.','varchar(300)') AS cNameParametr,
						t.c.query('./cValueParametr').value('.','varchar(300)') AS cValueParametr
					FROM so.xValueProbe.nodes('/ProbeParameters/cResultProbe ') AS t(c)
					LEFT  JOIN dbo.dctMatParamLink mpl ON 
						(mpl.nParametrId = CONVERT(INT,t.c.query('./nParametrId').value('.','varchar(300)'))) 
					AND (mpl.nMaterialTypeId = dm.nMaterialTypeId)
					WHERE NULLIF(t.c.query('./cValueParametr').value('.','varchar(300)'),'') IS NOT NULL
					ORDER BY ISNULL(mpl.nSequence, 1024)
					FOR XML PATH(N'cResultProbe'), root(N'ProbeParameters')
				
				) AS xValueProbeSort	
					
			    ) AS vp
		
		DECLARE @tRowsModif dbo.IdIntTable --| Количество движений террикона с отсортированным хим. анализом.
		
		BEGIN TRAN
			
			--| Обновление хим. анализа движений в таблице "macHeapOperation".
			MERGE dbo.macHeapOperation dst  --| Данные будут сохранены в этой таблице.
			
			USING
			(
				--| Таблица с которой сравниваем. Формируем ее как результат выполнения запроса.
				SELECT
					nHeapId,
					nHeapOperationId,
					xValueProbeSort		
				FROM  #tData_3
				WHERE nIsHst = 0 --| Если движение из таблицы "macHeapOperation"
				 AND nIsSort = 1 --| и оно было отсортировано - значит, его следует обновить.
			) AS src (nHeapId, nHeapOperationId, xValueProbeSort)
			
			--| Критерии совпадений.
			ON (dst.nHeapId = src.nHeapId 
				AND dst.nHeapOperationId = src.nHeapOperationId) 
			 --| Совпали.
			WHEN MATCHED
				THEN UPDATE SET dst.xValueProbe = src.xValueProbeSort
			OUTPUT INSERTED.nHeapOperationId INTO @tRowsModif; --| Количество исправленных движений в 
									   --| табл. "macHeapOperation" 

			--| Обновление хим. анализа движений в таблице "macHeapHistory".
			MERGE dbo.macHeapHistory dst --| Данные будут сохранены в этой таблице.
			USING
			(
				--| Таблица с которой сравниваем. Формируем ее как результат выполнения запроса.
				SELECT
					nHeapId,
					nHeapOperationId,
					xValueProbeSort		
				FROM  #tData_3
				WHERE nIsHst = 1 --| Если движение из таблицы "macHeapHistory"
				 AND nIsSort = 1 --| и оно было отсортировано - значит, его следует обновить.
			) AS src (nHeapId, nHeapOperationId, xValueProbeSort)
			
			--| Критерии совпадений.
			ON (dst.nHeapId = src.nHeapId 
				AND dst.nHeapHistoryId = src.nHeapOperationId) 
			--| Совпали.
			WHEN MATCHED 
				THEN UPDATE SET dst.xValueProbe = src.xValueProbeSort
			OUTPUT INSERTED.nHeapHistoryId INTO @tRowsModif;--| Количество исправленных движений в 
								        --| табл. "macHeapHistory" 
		
		COMMIT TRAN
		--ROLLBACK TRAN

		--| Записываем в выходной параметр общее количество изменённых движений, 
		--| движений, у которых был отсортирован хим. анализ согласно порядка следования хим. компонентов.
		SET  @nRowCountModifOut = (SELECT COUNT(nid) FROM @tRowsModif)
		--SELECT @nRowCountModifOut
		
		--| Удаление временной таблицы #tData_3.
		IF OBJECT_ID(N'tempdb..#tData_3', N'U') IS NOT NULL 
			DROP TABLE #tData_3	
			
	END 
	
END TRY
BEGIN CATCH
		IF XACT_STATE() <> 0
		BEGIN
			ROLLBACK TRAN;
		END	
		
		--| Удаление временной таблицы #tData_3.
		IF OBJECT_ID(N'tempdb..#tData_3', N'U') IS NOT NULL 
			DROP TABLE #tData_3
				
		DECLARE @cUserErrMessage NVARCHAR(200) = Char(10) + 'Ошибка в процедуре "AlterSequenceValueProbeHeapOperation" (см.:' +
		                                         @@servername + '\' + DB_NAME() + '). '
		
		--> Процедура для возвращения исходных сведений об ошибке вызывающему приложению или пакету.
		EXEC dbo.int_Error_Return @cUserErrMessage 
		--> Процедура логирование ошибок
		EXEC dbo.Log_Error @cUserErrMessage
		RETURN (50000 + ISNULL(ERROR_NUMBER(),0))
END CATCH							 	
GO

