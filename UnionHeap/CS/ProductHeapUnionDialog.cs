// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Linq;
using System.Windows.Forms;
using System.Drawing;
using Itm.WClient.Com;
using Itm.WControls;

namespace otk_interunion
{

    /// <summary>
    /// Диалоговое окно объединения терриконов.
    /// В данном окне выбираются терриконы для объединения,   
    /// указываются параметры результирующего террикона.
    /// </summary>
    /// <remarks>
    /// Автор: Пантелеев М.Ю.
    /// Дата:  28.05.2015г.
    /// </remarks>
    public partial class ProductHeapUnionDialog : Form, ISQLCore, IARMGroups
    {

        #region Constructor
            
		public ProductHeapUnionDialog()
		{
			try
			{
				InitializeComponent();
				
				// Открытие доступа на запуск и чтение процедур.
				// Добавление процедуры по трем составляющим:
				// 1) ключ процедуры (синионим), 
				// 2) название процедуры в SQL-сервере без схемы, 
				// 3) назначение процедуры (v-чтение, e-редактирование)
				spc.AddProc(
					"GetMaterialUser", "GetMaterialUser", "v",
					"GetFractionUser", "GetFractionUser", "v",
					"GetHeap", "GetHeap", "v"
				);
			}
			catch (Exception ex)
			{
				// public class MessageBoxes from Itm.WClient.Com;
				MessageBoxes.Error(this, ex, "Ошибка открытия доступа на запуск и чтение процедур!");
				return;
			}
		}

        #endregion Constructor

        #region ISQLCore Members

           // ...

        #endregion

        #region IARMGroups Members

           // ...

        #endregion

        #region Public Properties

            /// <summary>
            /// Id террикона
            /// </summary>
            public int HeapId { private get; set; }

            /// <summary>
            /// Id материала
            /// </summary>
            public int? MaterialId { get; set; }

            /// <summary>
            /// Id фракции
            /// </summary>
            public int? FractionId { get; set; }

            /// <summary>
            /// Id расположения
            /// </summary>
            public int? PlaceId { get; set; }

            /// <summary>
            /// Id месторасположения из дерева подразделений.
            /// Если null, значит пользователь выбрал пункт меню "Все"
            /// следовательно, необходимо вывести все терриконы цеха.
            /// </summary>
            public int? UnitId { get; set; }

            /// <summary>
            /// Заблокировать изменение собственника (для терриконов, которые создают цеховики)
            /// </summary>
            public bool DisableOwner { private get; set; }

            /// <summary>
            /// Id собственника
            /// </summary>
            public int? OwnerId { get; set; }

            /// <summary>
            /// Подразделения
            /// </summary>
            public DataTable Units { private get; set; }

            /// <summary>
            /// Подразделения, из которых
            /// </summary>
            public DataTable AllowUnits { private get; set; }

            /// <summary>
            /// Примечание
            /// </summary>
            public string Note { get; set; }

            /// <summary>
            /// Список GUID'ов терриконов для слияния с терриконом из входной переменной HeapId.
            /// </summary>
            public string cHeapGUIDList { get; set; }

            /// <summary>
            /// Название террикона, в который будет выполнено слияние.
            /// </summary>
            public string NameHeap { get; set; }

        #endregion Public Properties

        #region Private Members

            DataTable dts = null; // Таблица для хранения рекордсета(списка терриконов).    
            DataRow requiredRow = null; // DataRow входного террикона в гриде.
            int nSumWidthColumnsGrid = 0; // Суммарная ширина столбцов главного грида. 

        #endregion Private Members

        #region Events Handlers

            private void ProductHeapUnionDialog_Load(object sender, EventArgs e)
            {
                try
		{
			if (!DesignMode)
			{
				// Загрузка справочников.
				LoadDicts();
				
				// Установка значений по умолчанию для справочников материалов и фракций в соответствии 
				// с параметрами входного террикона.
				itbMaterial.SelectedValue = MaterialId;
				itbFraction.SelectedValue = FractionId;

				// Загрузка терриконов в главный грид окна.
				RefreshSimilarHeaps();

			}
		}	
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка загрузки справочников и терриконов!");
			return;
		}
            }
			
	    // Выбор материала из справочника.
	    // (! будет время  - выполнить рефакторинг загрузки справочников).
            private void itbMaterial_ButtonClick(object sender, EventArgs e)
            {
                try
		{
			using (var dlg = new TableSelectionForm
				{
					Name = "dlgMaterial",
					Text = "Выбор материала",
					ValueColumnName = "nMaterialId",
					Width = 600,
					Height = 380
				})
				{
					dlg.AddTextColumn("Наименование материал",
						"cNameMaterial", DataGridViewAutoSizeColumnMode.Fill, 100, 100);
					SQLCoreInterfaceHelper.InitializeChildSQLCore(dlg, this);

					var itb = (ItmTextBox)sender;
					dlg.DataSource = itb.DataSource;
					dlg.SelectedValue = itb.SelectedValue;
					if (dlg.ShowDialog(this) == DialogResult.OK)
					{
						itb.SelectedValue = dlg.SelectedValue;
					}
				}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка выбора материала!");
			return;
		}	
            }
			
	    // Выбор фракции из справочника.
	    // (! будет время  - выполнить рефакторинг загрузки справочников).
            private void itbFraction_ButtonClick(object sender, EventArgs e)
            {
		try
		{		
			using (var dlg = new TableSelectionForm
			{
				Name = "dlgFraction",
				Text = "Выбор фракции",
				ValueColumnName = "nFractionId",
				Width = 600,
				Height = 380
			})
			{
				dlg.AddTextColumn("Наименование фракции",
					"cNameFraction", DataGridViewAutoSizeColumnMode.Fill, 100, 100);
				SQLCoreInterfaceHelper.InitializeChildSQLCore(dlg, this);

				var itb = (ItmTextBox)sender;
				dlg.DataSource = itb.DataSource;
				dlg.SelectedValue = itb.SelectedValue;
				if (dlg.ShowDialog(this) == DialogResult.OK)
				{
					itb.SelectedValue = dlg.SelectedValue;
				}
			}
		}		
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка выбора фракции!");
			return;
		}
            }
			
	    // Выбор площадки из справочника.
	    // (! будет время  - выполнить рефакторинг загрузки справочников).
            private void itbPlace_ButtonClick(object sender, EventArgs e)
            {
		try
		{	
			using (var dlg = new TableSelectionForm
			{
				Name = "dlgPlace",
				Text = "Выбор места",
				ValueColumnName = "nUnitId",
				Width = 600,
				Height = 380
			})
			{
				dlg.AddTextColumn("Наименование места",
					"cNameUnit", DataGridViewAutoSizeColumnMode.Fill, 100, 100);
				SQLCoreInterfaceHelper.InitializeChildSQLCore(dlg, this);

				var itb = (ItmTextBox)sender;
				dlg.DataSource = itb.DataSource;
				dlg.SelectedValue = itb.SelectedValue;
				if (dlg.ShowDialog(this) == DialogResult.OK)
				{
					itb.SelectedValue = dlg.SelectedValue;
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка выбора площадки!");
			return;
		}
            }
			
	    // Объединение терриконов.
            private void btOK_Click(object sender, EventArgs e)
            {
                try
		{
			if (Check()) // Проверка кол-ва выбранных терриконов и их масс.
			{
				if (CheckData()) // Проверка - все ли параметры результирующего террикона заполнены. 
				{

					// Формирование списка параметров результирующего террикона
					// (в данный террикон будет произведено слияние).
					NameHeap = tbName.Text.Trim();                // Название террикона;
					MaterialId = (int?)itbMaterial.SelectedValue; // материал;
					FractionId = (int?)itbFraction.SelectedValue; // фракция;
					PlaceId = (int?)itbPlace.SelectedValue;       // месторасположение;
					OwnerId = (int?)itbOwner.SelectedValue;       // цех - владелец;
					Note = tbNote.Text.Trim();                    // примечание.

					// Получаем список GUID'ов выбранных терриконов для объединения.
					if (dts.Rows != null)
					{
						// Список ID "прочеканных" терриконов.
						var ids = new List<int>(igMain.CheckedRowsIDs);
						
						if (ids.Count > 0)
						{
							cHeapGUIDList = "";
							// Цикл по строкам главного грида с терриконами.
							foreach (DataRow row in dts.Rows)
								// Цикл по списку ID "прочеканных" терриконов.
								for (int i = 0; i < ids.Count; i++) 
								{
									// Если террикон из главного грида – выбран, 
									// добавляем его GUID в строковую переменную.
									if (row.Field<int>("nHeapId").Equals(ids[i]))
										cHeapGUIDList += row.Field<Guid>("nGUID").ToString().ToUpper() + ",";
								}
							// Удаление последней запятой.
							cHeapGUIDList = cHeapGUIDList.Remove(cHeapGUIDList.Length-1, 1);
						}
					}

					DialogResult = DialogResult.OK;
				}
			}
		}		
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка объединения терриконов!");
			return;
		}
            }

            private void igMain_CheckedRowsChanged(object sender, EventArgs e)
            {
                RequiredProductHeapChecked();
            }

            private void ProductHeapUnionDialog_SizeChanged(object sender, EventArgs e)
            {
                // Задаём ширину столбца примечаний в зависимости от содержимого. 
                SetColumnWidth();
            }

            private void igMain_VisibleChanged(object sender, EventArgs e)
            {
                if (igMain.Visible && igMain.HilightRules.Count == 0)
                {
                    // Создание правил раскраски грида.
                    // AddHilightRules(); 
                }
            }

            private void llCommentTemplate_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
            {
                // Открытие контекстного меню со списком шаблонов названий террикона.
                cmsCommentTemplate.Show(llCommentTemplate, new Point(0, llCommentTemplate.Height + 8));
            }

            private void itbPlace_TextChanged(object sender, EventArgs e)
            {
                // При выборе склада - вызывается метод наполнения справочника шаблонов названий террикона
                // (номер склада учитывается при формировании шаблонов).
                CreateContextMenuStripItems();
            }
						
	    // Установка курсора в нужную позицию текстового поля с названием результирующего террикона.
	    // Пользователю останется только ввести цифровой номер нового террикона.
	    // Метод предназначен для упрощения работы пользователя (сокращает количество операции).
            private void cmsCommentTemplate_ItemClicked(object sender, ToolStripItemClickedEventArgs e)
            {
		try
		{	
			// Получаем выбранный пользователем шаблон названия террикона.
			string str = e.ClickedItem.Text.Trim();

			// Ищем первое вхождение подстроки "тер" в строку "str" без учёта регистра.
			int n = str.IndexOf("тер", StringComparison.CurrentCultureIgnoreCase);

			// Если вхождение было найдено(или переменная "str" оказалась пустая) 
			// выполняется установка курсора в нужную позицию TextBox'а, компоненту передаётся фокус.
			// Пользователю останется только ввести цифровой номер нового террикона.
			if (n != -1)
			{
				str = str.Insert(n, " ");
				tbName.Text = str;
				tbName.SelectionStart = n;
				tbName.SelectionLength = 0;
				tbName.Focus();
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка установки курсора в названии результирующего террикона!");
			return;
		}
            }

        #endregion Events Handlers

        #region Private Methods

            /// <summary>
            /// Загрузка справочников: материалов, фракций, складов, шаблонов названий террикона.
            /// </summary>
            private void LoadDicts()
            {
                try
		{	
			// Загрузка справочника материалов.
			var mats = ExceptionWrapper.ProcessResult(
				() => spc.FillTable("GetMaterialUser"));
			itbMaterial.DisplayMember = "cNameMaterial";
			itbMaterial.ValueMember = "nMaterialId";
			itbMaterial.DataSource = mats;

			if (MaterialId.HasValue)
				itbMaterial.SelectedValue = MaterialId.Value;

			// Загрузка справочника фракций.
			var fracs = ExceptionWrapper.ProcessResult(
				() => spc.FillTable("GetFractionUser"));
			itbFraction.DisplayMember = "cNameFraction";
			itbFraction.ValueMember = "nFractionId";
			itbFraction.DataSource = fracs;

			if (FractionId.HasValue)
				itbFraction.SelectedValue = FractionId.Value;

			// Если известен список разрешённых подраздлений,
			// то подставим его, иначе - все подразделения.
			itbPlace.DisplayMember = "cFullNameUnit";
			itbPlace.ValueMember = "nUnitId";
			itbPlace.DataSource = AllowUnits ?? Units;

			if (PlaceId.HasValue)
				itbPlace.SelectedValue = PlaceId.Value;

			itbOwner.DisplayMember = "cFullNameUnit";
			itbOwner.ValueMember = "nUnitId";
			itbOwner.DataSource = Units;

			if (OwnerId.HasValue)
				itbOwner.SelectedValue = OwnerId.Value;

			// Собственника можно менять только диспетчеру.
			if (DisableOwner)
				itbOwner.Enabled = false;

			// Наполнение справочника шаблонов названий террикона(результата объединения).
			CreateContextMenuStripItems();
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка загрузки справочников!");
			return;
		}
            }

            /// <summary>
            /// Проверка: 
	    ///  1) количества выбранных терриконов (не менее 2-х), 
	    ///	 2) наличие терриконов с отрицательной массой.
            /// </summary>
            private bool Check()
            {
		try
		{
			bool res = true;

			// Проверка кол-ва выбранных терриконов
			if (igMain.CheckedRows.Count < 2)
			{
				MessageBox.Show("Нельзя объединить менее двух терриконов. \nПожалуйста, выберите ещё терриконы для объединения.",
				"Объединение терриконов", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
				res = false;
			}
			
			// Проверка выбранных терриконов на отрицательную массу.
			if (res == true)
			{
				// Цикл по "прочеканным" строкам.
				for (int i = 0; i < igMain.CheckedRows.Count; i++)
					// Если у террикона вес not null
					if ( !igMain.CheckedRows[i].Cells["colSHWeight"].Value.Equals(DBNull.Value))
						
						// если террикон имеет отрицательную массу
						if( (decimal)igMain.CheckedRows[i].Cells["colSHWeight"].Value < 0 )
						{
							MessageBox.Show("Объединение терриконов с отрицательной массой недопустимо!",
						 "Объединение терриконов", MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
						  res = false;

						  break; 
						}
			}

			return res;
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка в параметрах исходных терриконов!");
			return;
		}	
            }
            
            /// <summary>
            /// Проверка параметров результирующего террикона - все свойства должны быть указаны, 
            /// в противном случае, пустые поля на форме подсвечиваются красным.
            /// </summary>
            private bool CheckData()
            {
                var res = true;

                if (tbName.Text.Trim().Length == 0)
                {
                    epMain.SetError(tbName, "Введите наименование");
                    res = false;
                }

                if (itbMaterial.SelectedValue == null)
                {
                    epMain.SetError(itbMaterial, "Выберите материал");
                    res = false;
                }

                if (itbFraction.SelectedValue == null)
                {
                    epMain.SetError(itbFraction, "Выберите фракцию");
                    res = false;
                }

                if (itbPlace.SelectedValue == null)
                {
                    epMain.SetError(itbPlace, "Выберите место");
                    res = false;
                }

                return res;
            }

            /// <summary>
            /// 1) Принудительная установка checkbox'а для строки грида с входным терриконом.
	    /// 2) Динамическое формирование примечания результирующего террикона.
            /// </summary>
            private void RequiredProductHeapChecked()
            {
		try
		{
			// Принудительный выбор входного террикона
			if (!igMain.CheckedRowsIDs.Contains(HeapId))
			{
				igMain.CheckRow(requiredRow, true);
				igMain.Refresh();
			}

			// Динамическое формирование примечания.
			// Примечание состоит из названий терриконов, выбранных для слияния, и их параметров.
			if (dts.Rows != null)
			{
				string cNote ="";
				// Список ID "прочеканных" терриконов.
				var ids = new List<int>(igMain.CheckedRowsIDs);
				if (ids.Count > 0)
				{
					cNote = "Террикон создан в результате слияния терриконов: ";
					// Цикл по строкам главного грида с терриконами.
					foreach (DataRow row in dts.Rows)
						// Цикл по списку ID "прочеканных" терриконов.
						for (int i = 0; i < ids.Count; i++)
						{
							decimal nWeight = row.Field<decimal?>("nWeight") ?? 0;
							// Если террикон из главного грида выбран,
							// добавляем его в примечание.
							if (row.Field<int>("nHeapId").Equals(ids[i]))
								cNote += "\""
								   + row.Field<string>("cNameUnit") + "\\"  // название площадки;
								   + row.Field<string>("cNameHeap") + "\"(" // название террикона;
								   + row.Field<string>("cNameMaterial") + ", фр.:" // материал;
								   + row.Field<string>("cNameFraction").ToLower() + ", масса:"// фракция;
								   + nWeight.ToString() + " т.)"  // масса террикона.
								   + ", ";
						}
				}
				// Удаление символов " ," в конце строки.
				if (cNote.Length > 3)
				cNote = cNote.Remove(cNote.Length - 2, 2)+'.';

				// Отображение текста примечания.
				tbNote.Text = cNote;
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка формирования примечания результирующего террикона!");
			return;
		}
            }
            
            /// <summary>
            /// Загрузка терриконов в главный грид окна.
            /// Если указан ID склада - в выборку попадут терриконы склада,
            /// если ID не указан - ХП вернёт все терриконы цеха. 
            /// </summary>
            private void RefreshSimilarHeaps()
            {
		try
		{
			// 1) вызов ХП осуществляющей выборку терриконов, 
			// 2) сохранение рекордсета в переменную "dts".
			dts = ExceptionWrapper.ProcessResult(
				   () => spc.FillTable("GetHeap",
					   "nUnitIdIn", UnitId, SqlDbType.Int, //если null - ХП вернёт все терриконы цеха.
					   "nOwnerIdIn", OwnerId, SqlDbType.Int,
					   "nMaterialIdIn", null, SqlDbType.Int,
					   "nFractionIdIn", null, SqlDbType.Int,
					   "nIsDel", 0, SqlDbType.Int
					   ),
				   "Ошибка получения списка терриконов",
				   this
			   );
			
			// Загрузка полученного рекордсета в грид.
			igMain.DataSource = dts;

			// Запомним DataRow требуемого террикона.
			if (dts != null && dts.Rows.Count > 0)
			{
				requiredRow = dts.AsEnumerable()
					.Where(row => row.Field<int>("nHeapId").Equals(HeapId))
					.FirstOrDefault();
				
				// Сортировка терриконов по складам.
				igMain.Sort(igMain.Columns["colSHPlace"], ListSortDirection.Descending);
				// Сброс выделения строки по умолчанию
				igMain.ClearSelection();
				// Check записи в гриде с входным терриконом.
				igMain.CheckRow(requiredRow, true);
			}
			// Получаем cуммарную ширину столбцов главного грида. 
			WidthVisibleColumnsGrid(igMain);
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка наполнения главной таблицы!");
			return;
		}
            }

            /// <summary>
            /// Наполнение справочника шаблонов названий террикона(результата объединения).
            /// Некоторые из шаблонов формируются в соответствии с выбранным складом, 
            /// на котором, будет храниться результирующий террикон. 
            /// </summary>
            private void CreateContextMenuStripItems()
            {
		try
		{
			// Очищение контекстного меню(списка шаблонов).
			cmsCommentTemplate.Items.Clear();

			string str = itbPlace.Text;// Получаем название склада.

			// Поиск первого вхождение подстроки "склад" в строку "str" без учёта регистра.
			int n = str.IndexOf("склад",StringComparison.CurrentCultureIgnoreCase);
			
			// Если выбранное подразделение оказалось складом
			if (n != -1)
			{
				// ищем позицию с которой начинается номер склада
				int x = str.IndexOf("№", StringComparison.CurrentCultureIgnoreCase);
				
				// если у склада существует номер - получаем его.
				if (x != -1)
				{
					string numb = "";
					// Цикл по строке с названием склада с позиции "№" + "пробел"
					for (int i = x + 1; i < str.Length; i++)
					{
						// Считаем, что это номер до тех пор пока не встретился пробел
						if (str[i].ToString() != " ") 
							// и выбранный символ есть число
							if (Char.IsLetterOrDigit(str[i])) 
								numb = numb + str[i];
							else break;
					}
					
					// Шаблоны с номером склада.
					// Если номер склада был получен – используем его для создания шаблонов.
					if (numb != "")
					{
						cmsCommentTemplate.Items.Add(new ToolStripMenuItem(numb + " скл. тер. (слияние)"));
						cmsCommentTemplate.Items.Add(new ToolStripMenuItem(numb + " скл. террикон"));
						cmsCommentTemplate.Items.Add(new ToolStripMenuItem(numb + " скл. тер."));
					}
				}
			}
			// Стандартные шаблоны.
			cmsCommentTemplate.Items.Add(new ToolStripMenuItem("террикон"));
			cmsCommentTemplate.Items.Add(new ToolStripMenuItem("тер."));
			
			// P.S. Текущая реализация справочника, содержащего константные шаблоны названий результирующего террикона, 
			//      является экспериментальным решением. Если данная функция будет оценена пользователями положительно, 
			//      загрузку шаблонов правильнее будет реализовывать путём выборки 
			//      из соответствующей таблицы в БД.

		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка наполнения справочника шаблонов названий террикона!");
			return;
		}
				
            }
            
            /// <summary>
            /// Метод получает cуммарную ширину столбцов главного грида. 
            /// </summary>
            private void WidthVisibleColumnsGrid(object sender)
            {
		try
		{
			nSumWidthColumnsGrid = 0;
			DataGridView dg = (DataGridView)sender;

			// Расширяем столбец по содержимому.
			igMain.Columns["colNote"].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCellsExceptHeader;

			// Получаем cуммарную ширину столбцов.
			for (int i = 0; i < dg.ColumnCount; i++)
			{
				if (dg.Columns[i].Visible == true)
					nSumWidthColumnsGrid += dg.Columns[i].Width;
			}
			
			// Задаём ширину столбца примечаний в зависимости от содержимого. 
			SetColumnWidth();
		}
		catch (Exception ex)
		{
			MessageBoxes.Error(this, ex, "Ошибка расчёта суммарной ширины полей таблицы!");
			return;
		}
            }
            
            /// <summary>
            /// Метод задаёт ширину столбца примечаний в зависимости от содержимого.
            /// </summary>
            private void SetColumnWidth()
            {
		try
		{
			if (igMain.RowCount > 0)
			{
				// Если суммарная ширина столбцов меньше ширины грида (виден тёмный фон)
				if ((nSumWidthColumnsGrid < igMain.Width) &&
					// при этом, столбец по размеру не растянут (относительно ширины грида).
					(igMain.Columns["colNote"].AutoSizeMode != DataGridViewAutoSizeColumnMode.Fill))
				{
					// тогда, ширина столбца устанавливается по ширине грида.
					// Необходимо для того, чтобы при коротких комментариях 
					// тёмный цвет заднего фона грида не маячил на фоне. 
					igMain.Columns["colNote"].AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill;
				}

				// Если суммарная ширина столбцов больше ширины грида 
				if ((nSumWidthColumnsGrid > igMain.Width) &&
					// при этом, столбец по ширине заканчивается на ширине грида (текст, выходящий
					// за пределы, не помещается).
					(igMain.Columns["colNote"].AutoSizeMode != DataGridViewAutoSizeColumnMode.DisplayedCellsExceptHeader))
				{
					// тогда, ширина столбца устанавливается по содержимому.
					// Необходимо для того, чтобы появился нижний управляющий бегунок 
					// для просмотра полного текста примечания, уходящего за пределы окна.
					igMain.Columns["colNote"].AutoSizeMode = DataGridViewAutoSizeColumnMode.DisplayedCellsExceptHeader;
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка форматирования таблицы!");
			return;
		}
            }
            
            /*
            /// <summary>
            /// Создание правил раскраски грида.
            /// </summary>
            private void AddHilightRules()
            {
                // Террикон с отрицательной массой.
                igMain.HilightRules.Add
                (
                    new Itm.WControls.Grid.HilightRule
                    {
                        Color = Color.LightSalmon,
                        Description = "Террикон с отрицательной массой",
                        FilterExpr = "nWeight < 0"
                    }

                );

            } */

        #endregion Private Methods

    }
}

