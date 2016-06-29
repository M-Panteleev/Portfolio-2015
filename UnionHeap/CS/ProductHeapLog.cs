// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

using System;
using System.Collections;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using System.Xml.Linq;
using Itm.WClient.Com;

namespace otk_interunit
{
	
    /// <summary>
    /// Журнал учёта терриконов для цехов.
    /// В этом журнале можно просматривать состояние терриконов по всему заводу, 
    /// но управлять можно только "своими" терриконами.
    /// </summary>
    /// <remarks>
    /// Автор: Родшелев С.А.
    /// Ред: 				 Пантелеев М.Ю.
    /// Дата: 				 28.05.2015г.
    /// </remarks>
    public partial class ProductHeapLog : UserControl, ISQLCore, IARMGroups
    {
        #region Constructor

        public ProductHeapLog()
        {
            InitializeComponent();

		//...

            spc.AddProc(
                
		//...
				
                // Добавил: Пантелеев М.Ю.
                // Дата: 28.05.2015г.
		// Открытие доступа на запуск и чтение процедур.
                // Добавление процедуры по трем составляющим:
                // 1) ключ процедуры (синионим), 
                // 2) название процедуры в SQL-сервере без схемы, 
                // 3) назначение процедуры (v-чтение, e-редактирование)
                "UnionHeap", "UnionHeap", "e", // ХП объединения терриконов.
                "UndoUnionHeap", "UndoUnionHeap", "e" // ХП отмены объединения терриконов.
            );
        }

        #endregion Constructor
		
	//...

        #region Control Events

            //...
			
            // Добавил: Пантелеев М.Ю.
            // Дата: 28.05.2015г.
            private void tsbUnion_Click(object sender, EventArgs e)
            {
                UnionHeap();
            }

            private void tsbUndoUnion_Click(object sender, EventArgs e)
            {
                UndoUnionHeap();
            }
			
        #endregion Events Handlers

        #region Private Methods

	    //...

	    // Обработка активности кнопок на панели.
            private void SetToolButtonsEnabled()
            {
                //...
                
		// Добавил: Пантелеев М.Ю.
                // Дата: 28.05.2015г.
                // united = true, если:
		//	1)выбранный террикон;
		//	2)образован в результате объединения.
                var united = selected && igMain.SelectedDataRow["nIsUnion"].Equals(true);

                //...
                
		// Добавил: Пантелеев М.Ю.
                // Дата: 28.05.2015г.
                // Кнопка "Объединение терриконов" доступна если: 
		//	1)выбранный террикон; 
		//	2)не закрыт.
                tsbUnion.Enabled = selected && !closed;
                
		// Кнопка "Отмена объединения терриконов" доступна если: 
                // 	1)выбранный террикон;
		// 	2)образованный в результате объединения; 
		//	3)не закрыт.
                tsbUndoUnion.Enabled = united && !closed;
            }

	    //...          
           
            /// <summary>
            /// Объединение терриконов.
            /// Метод производит открытие одноимённого окна и при положительном исходе
	    ///	осуществляет вызов соответствующей хранимой процедуры.
            /// </summary>
            /// <remarks>
            /// Автор: Пантелеев М.Ю.
            /// Дата: 28.05.2015г.
            /// </remarks>
            private void UnionHeap()
            {
		try
		{
			using (var dlg = new ProductHeapUnionDialog())// Создание экземпляра окна "Объединение терриконов".
			{
				var row = igMain.SelectedDataRow;
				
				// Если террикон для объединения выбран
				if (row != null)
				{
					SQLCoreInterfaceHelper.InitializeChildSQLCoreNonControl(dlg, this);
					// задаются входные параметры окна "Объединение терриконов".
					dlg.HeapId = row.Field<int>("nHeapId"); // Идентификатор террикона.
					dlg.MaterialId = row.Field<int>("nMaterialId"); // ID материала террикона.
					dlg.FractionId = row.Field<int>("nFractionId"); // ID фракции террикона.
					dlg.AllowUnits = UseUnitsList ? dtUnitsForWorkshop : null; // Список разрешённых подраздлений.
					dlg.DisableOwner = UseUnitsList;// Собственника можно менять только диспетчеру.
					dlg.Units = dtUnits; // Все подразделения
					dlg.OwnerId = UseOwnerId ? nUnitId : null; // Подразделение-владелец.
					dlg.PlaceId = GetSelectedUnitId() ?? row.Field<int>("nUnitId");// ID склада из дерева либо ID склада выбранного террикона.
					dlg.UnitId = GetSelectedUnitId();// ID склада из дерева подразделений.

					// Настраиваются размеры окна "Объединение терриконов" относительно родительского.
					if (Width > 1185)
						dlg.Width = 1180;
					else
						dlg.Width = Width - 20;
					
					// Проверка веса на null (терриконы с весом null или 0 допустимы для объединения).
					if (!row.Field<decimal?>("nWeight").Equals(null))
					   
						// Выбранный террикон проверяется на отрицательную массу.
						if (row.Field<decimal>("nWeight") < 0)
						{
							MessageBox.Show("Выбран террикон с отрицательной массой. \nОперация объединения недопустима.",
							 "Объединение терриконов", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
							return;
						}
					// Открытие окна "Объединение терриконов" с ожиданием операции закрытия. 
					// Если в результате окно было закрыто нажатием кнопки "Применить" 
					// (все необходимые проверки прошли успешно)- осуществляется 
					// вызов ХП объединения терриконов с передачей входных параметров.
					if (dlg.ShowDialog() == DialogResult.OK) 
					{
					   // Вызов ХП объединения терриконов с передачей входных параметров.
					   ExceptionWrapper.ProcessNoResult(
					   () =>
						{       
							spc.ExecuteNonQuery("UnionHeap",
								"cNameHeapIn", dlg.NameHeap, SqlDbType.NVarChar, // Название террикона(результата объединения).
								"nMaterialIdIn", dlg.MaterialId, SqlDbType.Int,// ID материала террикона(результата объединения).
								"nFractionIdIn", dlg.FractionId, SqlDbType.Int,// ID фракции террикона(результата объединения).
								"nUnitIdIn", dlg.PlaceId, SqlDbType.Int,  // ID площадки на которой будет находится результирующий террикон.
								"nOwnerIdIn", dlg.OwnerId, SqlDbType.Int, // Цех-владелец террикона.
								"cNoteIn", dlg.Note, SqlDbType.NVarChar, // Текст примечания к террикону.
								"cHeapListIn", dlg.cHeapGUIDList, SqlDbType.NVarChar); // Список GUID'ов объединяемых терриконов (текстом, через запятую). 
						},
						"Ошибка объединения терриконов.",
						this);
					   
					   // Обновление списка терриконов в главном гриде.
					   RefreshGrid();

					}
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка открытия окна объединения терриконов!");
			return;
		}
            }

            /// <summary>
            /// Отмена операции объединения терриконов.
            /// Метод осуществляет вызов соответствующей хранимой процедуры в SQL сервере.
            /// </summary>
            /// <remarks>
            /// Автор: Пантелеев М.Ю.
            /// Дата: 28.05.2015г.
            /// </remarks>
            private void UndoUnionHeap()
            {
		try
		{
			// Формируем сообщение.
			var message = string.Format("Вы действительно желаете отменить объединение терриконов?");
			
			// Выводим предупреждение и ожидаем решения пользователя.
			var res = MessageBox.Show(message, "Отмена объединения терриконов", MessageBoxButtons.YesNo,
				MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);

			// Если был получен положительный ответ
			if (res == DialogResult.Yes)
			{
				var row = igMain.SelectedDataRow;

				// и террикон выбран
				if (row != null)
				{
					// Вызываем хранимую процедуру отката операции объединения.
					ExceptionWrapper.ProcessNoResult
					(
						() =>
						{
							spc.ExecuteNonQuery("UndoUnionHeap",
								"nHeapGUIDIn", row["nGUID"], SqlDbType.UniqueIdentifier);
						},
						"Ошибка отмены объединения терриконов.",
						this
					);
					// Обновление списка терриконов в главном гриде.
					RefreshGrid();
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка отмены операции объединения терриконов!");
			return;
		}
            }

        #endregion Private Methods

        //...

    }
}

