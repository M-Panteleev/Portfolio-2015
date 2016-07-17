// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Xml.Linq;
using Itm.WClient.Com;
using Itm.WControls;

namespace otk_interunit
{
    
    public partial class AlterHeapLog : UserControl, ISQLCore, IARMGroups
    {

        /////////////////////////////////////////////////////////////////////////////////
        ///
        /// Модуль:       AlterHeapLog
        /// 
        /// Назначение:   Отображение истории изменений параметров терриконов.
        ///               Модуль разработан для удобства администрирования.
        ///               Изменение параметров терриконов осуществляются планировщиком
        ///               в автоматическом режиме, текущий модуль отображает 
        ///               историю этих изменений, информацию:
        ///                 - о том, какими параметрами террикон обладал до изменения; 
        ///                 - какими стали параметры после изменения;
        ///                 - дату обновления параметров и т.д.
        ///               
        /// Автор:        Пантелеев М.Ю.
        /// Ред.:                        Пантелеев М.Ю.
        /// Дата:         18.02.2015г.   27.02.2015г.
        ///
        /////////////////////////////////////////////////////////////////////////////////


        #region Constructor

        public AlterHeapLog()
        {
            	try
		{
			InitializeComponent();
	
			// Открытие доступа на запуск чтение ХП "GetAlterHeapLog".
			// Добавление процедуры по трем составляющим:
			// 1) ключ процедуры (синионим), 
			// 2) название процедуры в Sql-сервере без схемы, 
			// 3) назначение процедуры (v-чтение, e-редактирование)
			spc.AddProc("GetAlterHeapLog", "GetAlterHeapLog", "v");
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

        #region Private Members

            #region Keys variables - определение переменных, фиксирующих факт нажатия клавиш.

                // "MouseButtonsLeft" - фиксирует факт зажатия левой кнопки мыши в активном гриде.
                // Переменная используется в "igMain_SelectionChanged" с целью предотвращения 
                // многократного выполнения метода при каждой вновь выбранной ячейке 
                // или строке(в процессе выделения).
                // Устанавливается в "MyMouseDown".
                // Используется в "igMain_SelectionChanged".
                // Сбрасывается в "igMain_MouseUp".
                private bool MouseButtonsLeft = false;

                // "Ctrl" - фиксирует факт зажатия клавиши Ctrl в активном гриде.
                // Устанавливается в "MyKeyDown".
                // Используется в "igMain_SelectionChanged".
                // Сбрасывается в "MyKeyDown", "igMain_KeyUp".
                private bool Ctrl = false;

                // "Shift" - фиксирует факт зажатия клавиши Shift в активном гриде.
                // Устанавливается в "MyKeyDown".
                // Используется в "igMain_SelectionChanged".
                // Сбрасывается в "MyKeyDown", "igMain_KeyUp".
                private bool Shift = false;

                // "Ctrl_C" - фиксирует факт нажатия cочетания клавиш Ctrl+C в активном гриде.
                // Определяется в "MyKeyDown".
                // Используется в "MyKeyPress"
                private bool Ctrl_C = false;

                // "Ctrl_CH" - фиксирует факт нажатия cочетания клавиш Ctrl+C, а затем H 
                // (Ctrl+C,H) в активном гриде.
                // Устанавливается в "MyKeyDown".
                // Используется в "CopySelectedRowsToClipboard".
                // Сбрасывается в "MyKeyDown".
                private bool Ctrl_CH = false;
           
            #endregion Keys variables
            
            // Используется в методе "AlterHeapLog_Load".
            bool isLoaded; 
	
		try
		{
			// Необходимо для получения длинны строки textBox ("tbReason").  
			[DllImport("user32.dll", EntryPoint = "SendMessageA")]
			private static extern int SendMessage_Ex(IntPtr hwnd, int wMsg, int wParam, StringBuilder lParam);
			private const int EM_GETLINECOUNT = 0x00BA;

			// Необходимо для cнятия блокировки буфера перед записью.
			[DllImport("user32.dll", CharSet = CharSet.Unicode)]
			private static extern int CloseClipboard();
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка объявления переменной из подключаемой библиотеки!");
			return;
		}
			
            // Переменная "nFirstSelectedCellsColumnIndex" предназначена для хранения № столбца 
            // первой выбранной ячейки из группы выделения(в гриде "igMain").
            // Устанавливается в "MyCellEnter".
            // Используется в "MyCellEnter".
            // Сбрасывается в "igMain_MouseUp", "MyMouseDown"
            private int nFirstSelectedCellsColumnIndex = -1;

            // Переменная "dt" предназначена для хранения набора данных полученных от ХП, 
            // с возможностью доступа внутри проекта. 
            // Устанавливается в "RefreshMainGrid".
            // Используется в "igMain_SelectionChanged".
            private DataTable dt = null;

            // Переменная "dr" предназначена для хранения набора данных выбранной (в igMain) строки 
            // с возможностью доступа внутри проекта.
            // Используется в режиме igMain.SelectionMode.CellSelect.
            // Устанавливается в "igMain_SelectionChanged".
            // Используется в "igMain_SelectionChanged".
            private DataRow dr = null;

        #endregion Private Members
        
        #region Events Handlers

            // Метод, стартующий при открытии текущего документа в клиенте.
            private void AlterHeapLog_Load(object sender, EventArgs e)
            {
		try
		{
			if (!DesignMode && !isLoaded)
			{
				isLoaded = true;

				using (var wf = new WaitForm())
				{
					// Отображение процесса загрузки при первом открытии приложения.
					wf.BeginBlockedFirstStage(this, "Подождите, пожалуйста...", "Чтение справочников...");
					wf.BlockedNextStage("Загрузка истории изменений терриконов...", 90);

					// Наполнение главного грида данными, полученными из ХП.
					RefreshMainGrid(); 
					
					wf.EndBlocked(this);
				}
				
				// Установка значения фильтра времени по умолчанию (см. на верхней панели журнала).
				// Значение по умолчанию: "Месяц"  (записи старше месяца в таблице логов не хранятся).
				itsMain.SelectedInterval = Itm.WControls.ItmToolStrip.DateInterval.Month;

				// Добавление разделителей в контекстные меню 4-х гридов журнала.
				#region CreateContextMenuStripSeparator
					igMain.ContextMenuStrip.Items.Insert(7, new ToolStripSeparator());
					igHeapParameters.ContextMenuStrip.Items.Insert(7, new ToolStripSeparator());
					igValueProbeAfter.ContextMenuStrip.Items.Insert(7, new ToolStripSeparator());
					igValueProbeBefore.ContextMenuStrip.Items.Insert(7, new ToolStripSeparator());
				#endregion CreateContextMenuStripSeparator

				// Добавление пункта "Копировать" в контекстные меню 4-х гридов журнала.
				#region CreateContextMenuStripItemsCopy

					// Вставка в нужную позицию контекстного меню грида "igMain".
					igMain.ContextMenuStrip.Items.Insert(8, new ToolStripMenuItem("Копировать Ctrl+C", null, null, "Copy"));
					var item1 = igMain.ContextMenuStrip.Items[8];
					// Назначение события.
					item1.Click += CopySelectedRowsToClipboard;
					// Указание грида, к которому привязано данное контекстное меню.
					// Используется для определения грида-источника в методе "CopySelectedRowsToClipboard"
					item1.Tag = igMain;

					igHeapParameters.ContextMenuStrip.Items.Insert(8, new ToolStripMenuItem("Копировать Ctrl+C", null, null, "Copy"));
					var item2 = igHeapParameters.ContextMenuStrip.Items[8];
					item2.Click += CopySelectedRowsToClipboard;
					item2.Tag = igHeapParameters;

					igValueProbeAfter.ContextMenuStrip.Items.Insert(8, new ToolStripMenuItem("Копировать Ctrl+C", null, null, "Copy"));
					var item3 = igValueProbeAfter.ContextMenuStrip.Items[8];
					item3.Click += CopySelectedRowsToClipboard;
					item3.Tag = igValueProbeAfter;

					igValueProbeBefore.ContextMenuStrip.Items.Insert(8, new ToolStripMenuItem("Копировать Ctrl+C", null, null, "Copy"));
					var item4 = igValueProbeBefore.ContextMenuStrip.Items[8];
					item4.Click += CopySelectedRowsToClipboard;
					item4.Tag = igValueProbeBefore;

				#endregion CreateContextMenuStripItemsCopy

				// Добавление пункта "Копировать с заголовками" в контекстные меню 4-х гридов журнала.
				#region CreateContextMenuStripItemsCopyWithHeader

					// Вставка в нужную позицию контекстного меню грида "igMain".
					igMain.ContextMenuStrip.Items.Insert(9, new ToolStripMenuItem("Копировать с заголовками Ctrl+C, H", null, null, "CopyWithHeader"));
					var item5 = igMain.ContextMenuStrip.Items[9];
					// Назначение события.
					item5.Click += CopySelectedRowsToClipboard;
					// Указание грида, к которому привязано данное контекстное меню.
					// Используется для определения грида-источника в методе "CopySelectedRowsToClipboard"
					item5.Tag = igMain;

					igHeapParameters.ContextMenuStrip.Items.Insert(9, new ToolStripMenuItem("Копировать с заголовками Ctrl+C, H", null, null, "CopyWithHeader"));
					var item6 = igHeapParameters.ContextMenuStrip.Items[9];
					item6.Click += CopySelectedRowsToClipboard;
					item6.Tag = igHeapParameters;

					igValueProbeAfter.ContextMenuStrip.Items.Insert(9, new ToolStripMenuItem("Копировать с заголовками Ctrl+C, H", null, null, "CopyWithHeader"));
					var item7 = igValueProbeAfter.ContextMenuStrip.Items[9];
					item7.Click += CopySelectedRowsToClipboard;
					item7.Tag = igValueProbeAfter;

					igValueProbeBefore.ContextMenuStrip.Items.Insert(9, new ToolStripMenuItem("Копировать с заголовками Ctrl+C, H", null, null, "CopyWithHeader"));
					var item8 = igValueProbeBefore.ContextMenuStrip.Items[9];
					item8.Click += CopySelectedRowsToClipboard;
					item8.Tag = igValueProbeBefore;

				#endregion CreateContextMenuStripItemsCopyWithHeader
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка формирования контекстного меню!");
			return;
		}	
            }

            // Обновление содержимого главного грида(igMain) по клику на кнопке "Показать все".
            private void tsAll_Click(object sender, EventArgs e)
            {
                RefreshMainGrid();
            }

            // Обновление содержимого главного грида(igMain) по клику на кнопке "Обновить".
            private void itsMain_OnRefresh(object sender, EventArgs e)
            {
                RefreshMainGrid();

            }

            // Раскраска главного грида(igMain) при изменении его содержимого.
            private void igMain_VisibleChanged(object sender, EventArgs e)
            {
                // Если грид видим и не одного правила раскраски ещё не создано.
                if (igMain.Visible && igMain.HilightRules.Count == 0)
                    AddMainGrigHilight();
            }

            // Раскраска грида "Хим. состав до изм."(igValueProbeBefore) при изменении его содержимого.
            private void igValueProbeBefore_VisibleChanged(object sender, EventArgs e)
            {
                // Если грид видим и не одного правила раскраски ещё не создано.
                if (igValueProbeBefore.Visible && igValueProbeBefore.HilightRules.Count == 0)
                    AddProbeBeforeGrigHilight();
            }

            // Наполнение вспомогательных гридов при выборе записи в главном(igMain), а также,
            // формирование и вывод на экран списка причин, повлиявших на 
            // изменение параметров террикона в таблице "macHeap".
            private void igMain_SelectionChanged(object sender, EventArgs e) 
            {
                try
		{
			// Расчёты должны выполняться если:
			if (
				// 1)В гриде igMain НЕ происходит выделение ячеек с 
				// помощью зажатой кнопки мыши.
				MouseButtonsLeft != true
				// 2)В гриде igMain НЕ происходит выделение ячеек с
				// помощью стрелок и зажатой клавиши Shift.
				&& Shift != true
				// 3)В гриде igMain НЕ происходит выделение ячеек с
				// помощью стрелок и зажатой клавиши Ctrl.
				&& Ctrl != true)
			{
				
				//Очистка textBox'а со списком причин.
				tbReason.Text = string.Empty;

				//Счётчик кол-ва причин.
				int nCountReason = 0;

				// Получение набора данных выбранной строки 
				// в режиме igMain.SelectionMode = CellSelect
				if (
					// Если igMain не пустой;
					igMain.Rows.Count > 0
					// Если в igMain НЕ выделена вся строка (как например, при 
					// igMain.SelectionMode = FullRowSelect) т.е. 
					// пользователь кликнул по ячейке вне заголовков строк.
					&& igMain.SelectedDataRow == null
					// Если НЕ происходит выделение ячеек с помощью зажатой кнопки мыши.
					&& MouseButtonsLeft == false)
					// Тогда, получаем содержимое выбронной строки.
					dr = dt.Rows[igMain.CurrentCell.RowIndex];

				// Если в главном гриде выброна запись, либо
				// есть набор данных активной строки, полученный в режиме 
				// igMain.SelectionMode = CellSelect (см. if выше),
				// тогда выполняются дальнейшие действия
				if (igMain.SelectedDataRow != null || dr != null)
				{
					// Получение набора данных из выбранной строки главного грида.
					var row = (igMain.SelectedDataRow ?? dr);

					// Наполнение вспомогательного грида "Хим. состав до изм."
					RefreshChemAnalysis(row, igValueProbeBefore);

					// Наполнение вспомогательного грида "Хим. состав после изм."
					RefreshChemAnalysis(row, igValueProbeAfter);

					// Наполнение вспомогательного грида "Параметры"
					RefreshHeapParametersGrid(row);

					// Проверка хим. анализа ДО и ПОСЛЕ изменения на идентичность значений.
					// Необходимо для определения критерия отличий - чем отличаются, значениями или 
					// только порядком следования хим. компонентов.
					// Полученное в результате проверки значение (переменная bIsChemEquals) 
					// используется в блоке "PrintReason" см. ниже.
					int nEqualRowsCount = 0;
					bool bIsChemEquals = false;
					int nRowCount = igValueProbeBefore.Rows.Count;

					if (nRowCount > 0)
					for (int i = 0; i < nRowCount; i++)
					{
						if (igValueProbeBefore["cValueParametrBefore", i].Value.ToString() ==
							igValueProbeBefore["cValueParametrAfter", i].Value.ToString())
							nEqualRowsCount += 1;
					}
					if (nRowCount == nEqualRowsCount)
						bIsChemEquals = true;


					// Создание текстового разделителя (в зависимости от ширины textBox "tbReason").
					#region CreateTextBoxSeparator

					StringBuilder buffer = new StringBuilder("   ", 256);
					buffer[0] = (char) 256;

					int nLineCount = 0;
					int nLineLength = 0;
					while (nLineCount < 2)
					{
						nLineCount = SendMessage_Ex(tbReason.Handle, EM_GETLINECOUNT, 0, buffer);
						tbReason.Text += "-";
					}
					nLineLength = tbReason.Text.Length - 2;
					tbReason.Text = string.Empty;

					string cSeparator = " ";
					cSeparator = cSeparator.PadRight(nLineLength, '-') +
								 " " +
								 Environment.NewLine;

					#endregion CreateTextBoxSeparator

					#region PrintReason - вывод списка причин на экран.

						if (row["nIsUpdateText"].Equals("Ред."))
								tbReason.Text += "  Причины обновления:" + Environment.NewLine + 
											 cSeparator;

						if (!row["nHeapWeightBefore"].Equals(row["nHeapWeightAfter"]))
						{
							nCountReason += 1;
							tbReason.Text += "  Масса террикона в таблице \"macHeap\" не соответствовала " +
											 Environment.NewLine +
											 "  массе, расcчитанной согласно выполненных движений." +
											 cSeparator;
						}
						

						if (!row["cValueProbeBefore"].Equals(row["cValueProbeAfter"])
							&& bIsChemEquals == false)
						{
							nCountReason += 1;
							tbReason.Text += "  Хим. анализ террикона в таблице \"macHeap\" не соответствовал " +
											 Environment.NewLine +
											 "  рассчитанному хим. анализу согласно движений." +
											 cSeparator;
						}
						
						if (!row["cValueProbeBefore"].Equals(row["cValueProbeAfter"])
								&& bIsChemEquals == true)
						{
							nCountReason += 1;
							tbReason.Text += "  Хим. анализ террикона имел некорректный порядок следования" +
											 Environment.NewLine +
											 "  хим. компонентов." +
											 cSeparator;
						}

						if (row["nIsAlterHeapOp"].Equals(1))
						{
							nCountReason += 1;
							tbReason.Text += "  У террикона были обнаружены движения, имеющие в хим. составе " +
											 Environment.NewLine +
											 "  некорректный порядок следования хим. компонентов." +
											 Environment.NewLine +
											 "  Исправлено движений: " + row["nRowAlterHeapOp"] as string +
											 Environment.NewLine +
											 cSeparator;
						}

					#endregion PrintReason 

					// Отображение количества причин.
					lbCountReason.Text = nCountReason.ToString();

					// Если террикон не изменялся, ввиду корректности – 
					// на экран, вместо причин, выводится текст с описанием того, что у него все верно.
					if (row["nIsUpdateText"].Equals("Верно"))
					{
						tbReason.Text += "  Параметры террикона корректны." + Environment.NewLine +
										 cSeparator +
										 "  Хим. анализ террикона в таблице \"macHeap\" соответствует" +
										 Environment.NewLine +
										 "  проверочному." + Environment.NewLine +
										 cSeparator +
										 "  Хим. анализ террикона имеет корректный порядок следования " +
										 Environment.NewLine +
										 "  хим. компонентов." + Environment.NewLine +
										 cSeparator +
										 "  Масса террикона в таблице \"macHeap\" соответствует " +
										 Environment.NewLine +
										 "  рассчитанной массе согласно движений." + Environment.NewLine +
										 cSeparator +
										 "  Хим. анализ движений имеет корректный порядок следования " +
										 Environment.NewLine +
										 "  хим. компонентов." + Environment.NewLine +
										 cSeparator.Replace("\n", ""); //  Удаляем последнюю пустую строку - чтобы скрол не появлялся.
					}

				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка отображения параметров террикона!");
			return;
		}
            }

            // Отображение информации о последнем терриконе при выделении содержимого в нескольких 
            // строках igMain с помощью мыши.
            private void igMain_MouseUp(object sender, MouseEventArgs e)
            {
		try
		{
			// Отпущенная левая кнопка мыши говорит об окончании процесса выделения.
			if (e.Button == MouseButtons.Left)
			{
				// Сбрасываем статус зажатой левой кнопки мыши (кнопка отпущена).
				// Переменная используется в "igMain_SelectionChanged" с целью предотвращения 
				// многократного выполнения метода при каждой вновь выбранной ячейке 
				// или строке(в процессе выделения).
				MouseButtonsLeft = false;

				// Сбрасываем № столбца первой выбранной ячейки из группы выделения.
				// Данный статус необходим только в процессе выбора строк и ячеек.
				// Используется в "MyCellEnter".
				nFirstSelectedCellsColumnIndex = -1;

				if (igMain.Rows.Count > 0) // Если главный грид непустой
				{
					// осуществляем наполнение вспомогательных гридов и выводим на экран
					// список причин, повлиявших на изменение параметров террикона.
					igMain_SelectionChanged(igMain, null);
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка выделения ячеек таблицы с помощью мыши!");
			return;
		}
            }

            // Отображение инф-ции о последнем терриконе при выделении содержимого в нескольких 
            // строках igMain с помощью стрелок и зажатых клавиш Ctrl,Shift.
            private void igMain_KeyUp(object sender, KeyEventArgs e)
            {
		try
		{
			if (e.KeyData == Keys.ControlKey) // Если клавиша Ctrl отпущена
			{
				Ctrl = false; // сбрасываем статус.

				// Сбрасываем № столбца первой выбранной ячейки из группы выделения.
				// Данный статус необходим только в процессе выбора строк и ячеек.
				// Используется в "MyCellEnter".
				nFirstSelectedCellsColumnIndex = -1;

				if (igMain.Rows.Count > 0) // Если главный грид непустой
				{
					// осуществляем (в соответствии с последней выделенной строкой/ячейкой в igMain)
					// наполнение вспомогательных гридов и выводим на экран
					// список причин, повлиявших на изменение параметров террикона.
					igMain_SelectionChanged(igMain, null);
				}
			}

			if (e.KeyData == Keys.ShiftKey) // Если клавиша Shift отпущена.
			{
				Shift = false; // сбрасываем статус.

				// Сбрасываем № столбца первой выбранной ячейки из группы выделения.
				// Данный статус необходим только в процессе выбора строк и ячеек.
				// Используется в "MyCellEnter".
				nFirstSelectedCellsColumnIndex = -1;

				if (igMain.Rows.Count > 0) // Если главный грид непустой
				{
					// осуществляем (в соответствии с последней выделенной строкой/ячейкой в igMain)
					// наполнение вспомогательных гридов и выводим на экран
					// список причин, повлиявших на изменение параметров террикона.
					igMain_SelectionChanged(igMain, null);
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка выделения ячеек таблицы при помощи клавиш клавиатуры!");
			return;
		}
            }

        #endregion Events Handlers

        #region Private Methods

            // Наполнение главного грида (igMain) данными из ХП.
            private void RefreshMainGrid()
            {
		try
		{
			bool? nIsUpdate = true; // Входной параметр для ХП.

			// Столбец "Дата изменения" грида igMain виден только тогда,
			// когда активна кнопка "Показать все".
			igMain.Columns["dLastEditLog"].Visible = tsAll.Checked;

			// Если кнопка "Показать все" активна (см. на верхней панели) - 
			// в ХП в качестве входного параметра будет передано значение "null", что 
			// приведёт к получению всех типов записей таблицы логов за выбранный интервал времени.
			if (tsAll.Checked) nIsUpdate = null;

			// Вызов ХП "GetAlterHeapLog" с передачей входных параметров и 
			// сохранением рекордсета в переменную "dt".
			dt = ExceptionWrapper.ProcessResult(
				() => spc.FillTable("GetAlterHeapLog",
					"nHeapIdIn", null, SqlDbType.Int,
					"gHeapIn", null, SqlDbType.UniqueIdentifier,
					"nUnitIdIn", null, SqlDbType.Int,
					"nOwnerIdIn", null, SqlDbType.Int,
					"nIsUpdate", nIsUpdate, SqlDbType.Bit,
					"dDateBeginIn", itsMain.StartDate, SqlDbType.DateTime,
					"dDateEndIn", itsMain.EndDate, SqlDbType.DateTime
					),
				"Ошибка получения истории изменений терриконов.",
				this
			);

			// Форматирование содержимого некоторых полей набора данных, если эти данные получены.
			if (dt != null)
			{
				// Добавление нового столбца в набор данных для отображения статуса.
				dt.Columns.Add(
					new DataColumn("nIsUpdateText", typeof (string), "IIF(nIsUpdate, 'Ред.','Верно')"));

				// Добавление нового столбца в набор данных для отображения значений GUID.
				dt.Columns.Add(
					new DataColumn("nGUID_UpperCase", typeof(string), ""));

				// Наполнение столбца "nGUID_UpperCase" данными в верхнем регистре. 
				foreach (DataRow Row in dt.Rows)
				{
					Row["nGUID_UpperCase"] = Row["nGUID"].ToString().ToUpper();
				}
			}

			// Наполнение главного грида данными, полученными от ХП.
			if (dt != null)
			{
				igMain.DataSource = dt;
				
				// Установка фокуса на верхнюю строку грида.
				if (igMain.SelectionMode == DataGridViewSelectionMode.FullRowSelect
					&& igMain.Rows.Count > 0
					&& igMain.SelectedRows.Count == 0)
					igMain.Rows[0].Selected = true;
			}
			// Если в главном гриде не выбрана ни одна запись - выполняется  
			// очистка всех зависящих от него гридов.
			// Необходимо в ситуации, когда в основном гриде нет данных, а во вспомогательных 
			// остаётся висеть информация о последней выбранной записи.
			if (igMain.SelectedRows.Count == 0)
			{
				DataTable Empty = null;
				igHeapParameters.DataSource = Empty;
				igValueProbeBefore.DataSource = Empty;
				igValueProbeAfter.DataSource = Empty;
				tbReason.Text = string.Empty; //Очистка textBox'а со списком причин.
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка наполнения таблицы терриконов!");
			return;
		}
            }

            // Создание правил раскраски главного грида(igMain).
            private void AddMainGrigHilight() 
            {
                igMain.HilightRules.Add
                (
                    new Grid.HilightRule
                    {
                        Color = Color.LightCoral,
                        ColumnName = "nHeapWeightBefore",
                        Description = "Масса террикона отличается от проверочной.",
                        FilterExpr = "nHeapWeightBefore <> nHeapWeightAfter"
                    }
                );

                igMain.HilightRules.Add
                (
                    new Grid.HilightRule
                    {
                        Color = Color.LightGreen,
                        ColumnName = "nHeapWeightAfter",
                        Description = "Масса террикона рассчитанная согласно движений.",
                        FilterExpr = "nHeapWeightBefore <> nHeapWeightAfter"
                    }
                );

                igMain.HilightRules.Add
                (
                    new Grid.HilightRule
                    {
                        Color = Color.LightCoral,
                        ColumnName = "cStrValueProbeBefore",
                        Description = "Хим. анализ террикона отличается от расчётного.",
                        FilterExpr = "cStrValueProbeBefore <> cStrValueProbeAfter"
                    }
                );

                igMain.HilightRules.Add
                (
                    new Grid.HilightRule
                    {
                        Color = Color.LightGreen,
                        ColumnName = "cStrValueProbeAfter",
                        Description = "Хим. анализ рассчитанный согласно движений.",
                        FilterExpr = "cStrValueProbeBefore <> cStrValueProbeAfter"
                    }
                );

                igMain.HilightRules.Add
                (
                    new Grid.HilightRule
                    {
                        Color = Color.LightGreen,
                        ColumnName = "nIsUpdate",
                        Description = "Все параметры террикона до и после проверки совпадают.",
                        FilterExpr = "nIsUpdate = 0"
                    }
                );

                igMain.RefreshHilight();
              
            }

            // Создание правил раскраски грида "Хим. состав до изм."(igValueProbeBefore).
            private void AddProbeBeforeGrigHilight()
            {
                igValueProbeBefore.HilightRules.Add
                (
                   new Grid.HilightRule
                   {
                       Color = Color.LightCoral,
                       ColumnName = "cValueParametrBefore",
                       Description = "Знач. хим. компонента отличается от проверочного.",
                       FilterExpr = "cValueParametrBefore <> cValueParametrAfter"
                   }
                );
                
                igValueProbeBefore.HilightRules.Add
                (
                   new Grid.HilightRule
                   {
                       Color = Color.LightGreen,
                       ColumnName = "cValueParametrBefore",
                       Description = "Знач. хим. компонента cоответствует проверочному.",
                       FilterExpr = "cValueParametrBefore = cValueParametrAfter"
                   }
                );

                igValueProbeBefore.RefreshHilight();
            }

            // Наполнение грида "Параметры"(igHeapParameters) данными из выбранной строки в igMain.
            private void RefreshHeapParametersGrid(DataRow row)
            {
		try
		{
			if (row != null)
			{
				DataTable table = new DataTable();
				table.Columns.Add("cNameParametr", typeof(string));
				table.Columns.Add("cValueParametr", typeof(string));
				
				table.Rows.Add( "Название террикона:", row["cNameHeap"]);
				table.Rows.Add( "Дата изменения параметров:", row["dDateCreateLog"]);
				table.Rows.Add( "GUID террикона:", row["nGUID_UpperCase"]);
				table.Rows.Add( "Id террикона:", row["nHeapId"]);
				table.Rows.Add( "Id площадки:", row["nFirstUnitParentId"]);
				table.Rows.Add( "Месторасположение:", row["cFullNameUnit"]);
				table.Rows.Add( "Цех-владелец:", row["cOwnerName"]);
				table.Rows.Add( "Масса террикона до:", row["nHeapWeightBefore"]);
				table.Rows.Add( "Масса террикона после", row["nHeapWeightAfter"]);
				table.Rows.Add( "Хим. анализ до:", row["cStrValueProbeBefore"]);
				table.Rows.Add( "Хим. анализ после:", row["cStrValueProbeAfter"]);
				table.Rows.Add( "Масса входящих:", row["nSumWeight_In"]);
				table.Rows.Add( "Масса исходящих:", row["nSumWeight_Out"]);
				table.Rows.Add( "Дата последнего движения:", row["dDateLastOperation"]);
				table.Rows.Add( "Кол-во движ. с сорт. хим. анализом:", row["nRowAlterHeapOp"]);
				table.Rows.Add( "Дата создания террикона:", row["dDateCreateHeap"]);
				table.Rows.Add( "Дата последней "Зачистки" / "Замера":", row["dDateEvent"]);
				
				igHeapParameters.DataSource = table;
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка наполнения таблицы параметров!");
			return;
		}
            }

            // Получение количества вхождений подстроки (substr) в строку (str). 
            // Используется в методе "RefreshChemAnalysis" (см. ниже).
            public int PosCount(string substr, string str)
            {
                return str.Split(new string[] { substr }, StringSplitOptions.None).Length - 1;
            }

            // Метод используется для наполнение гридов "igValueProbeBefore" и "igValueProbeAfter" 
            // данными из выбранной строки в igMain.
            private void RefreshChemAnalysis(DataRow row, Itm.WControls.Grid grid)
            {
		try
		{
			// Табличная переменная для временного хранения 
			// значений хим. анализа террикона до и после изменения.
			DataTable dt = null;

			// Если в igMain была выбрана строка и передана в качестве входного параметра.
			if (row != null)
			{
				// Создание таблицы и набора полей для временного хранения
				// значений хим. анализа террикона ДО и ПОСЛЕ изменения.
				dt = new DataTable();
				dt.Columns.AddRange(
					new[]
					{
						new DataColumn("nParametrId", typeof (int)),
						new DataColumn("cNameParametrBefore", typeof (string)),
						new DataColumn("cValueParametrBefore", typeof (string)),
						new DataColumn("cNameParametrAfter", typeof (string)),
						new DataColumn("cValueParametrAfter", typeof (string))
					}
					);

				// Получение хим. анализ террикона ДО изменения (из строки igMain. В XML формате).
				var ChemBefore = row["cValueProbeBefore"].ToString();

				// Получение хим. анализ террикона ПОСЛЕ изменения (из строки igMain. В XML формате).
				var ChemAfter = row["cValueProbeAfter"].ToString();
				
				// Переменная для временного хранения элементов XML–данных.
				XElement el = null;
				
				// Определение анализа с максимальным количеством хим. компонентов.
				// Необходимо для корректного наполнения гридов.
				// Если какого-то компонента в хим. составе террикона ДО или ПОСЛЕ изменения 
				// не было, его всё равно необходимо отобразить, при этом,  
				// выделить цветом и показать, что значение отсутствовало.

				if (PosCount("<nParametrId>", ChemBefore) >= PosCount("<nParametrId>", ChemAfter))
					el = XElement.Parse(ChemBefore);

				if (PosCount("<nParametrId>", ChemBefore) < PosCount("<nParametrId>", ChemAfter))
					el = XElement.Parse(ChemAfter);

				// Формирование структуры табличной переменной "dt".
				// Столбцы переменной "dt" уже были указаны при её создании, теперь,
				// указываются строки (добавление вертикальной шапки).
				foreach (var e in el.Elements())
				{
					var r = dt.NewRow();
					r["nParametrId"] = Convert.ToInt32(e.Element("nParametrId").Value);
					r["cNameParametrBefore"] = e.Element("cNameParametr").Value;
					r["cNameParametrAfter"] = e.Element("cNameParametr").Value;
					dt.Rows.Add(r);
				}

				// Наполнение табличной переменной "dt" данными о хим. анализе 
				// террикона ДО изменения.
				EntryChemElementsIntoTempGrid(dt, ChemBefore, "Before");
				
				// Наполнение табличной переменной "dt" данными о хим. анализе 
				// террикона ПОСЛЕ изменения.
				EntryChemElementsIntoTempGrid(dt, ChemAfter, "After");
				
			}
			
			// Если текущий метод вызывается для грида "igValueProbeBefore" наполняем его 
			// без каких-либо проблем т.к. имена полей переменной "dt" идентичны 
			// именам полей "igValueProbeBefore".
			if (grid == igValueProbeBefore)
				grid.DataSource = dt;

			// В случае, если текущий метод вызывается для грида "igValueProbeAfter" 
			// перед его наполнением необходимо переименовать поля табличной переменной "dt"
			// таким образом, чтобы они соответсвовали названию полей "igValueProbeAfter".
			//
			// Данный костыль обусловлен тем, что для нескольких гридов формы 
			// нельзя использовать одинаковые названия полей.
			if (grid == igValueProbeAfter)
			{
				// Переименование полей табличной переменной "dt" для их
				// совпадения с именами полей грида "igValueProbeAfter".
				var ColNameReNamed = "";
				foreach (DataColumn Column in dt.Columns)
				{
					ColNameReNamed = Column.ColumnName;
					ColNameReNamed = ColNameReNamed.Replace("Before", "Bef");
					ColNameReNamed = ColNameReNamed.Replace("After", "Aft");
					Column.ColumnName = ColNameReNamed;
					//MessageBox.Show(ColNameReNamed);
				}

				// Наполнение грида "igValueProbeAfter" данными из табличной переменной "dt".
				grid.DataSource = dt;
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка наполнения таблиц информацией о хим. анализе до и после изменения!");
			return;
		}
            }
            
            // Метод осуществляет наполнение временной табличной переменной "dt" данными о хим. анализе 
            // террикона ДО и ПОСЛЕ изменения.
            // Используется в методе "RefreshChemAnalysis" (см. выше).
            private static void EntryChemElementsIntoTempGrid(DataTable dt, string Chem, string Postfix)
		{
			// Входные параметры:
			//
			//  dt      - ссылка на перемнную табличного типа, хранящую одновременно  
			//            хим. анализа террикона до и после изменения.
			//  Chem    - хим. анализ террикона в XML формате.
			//            Значения: 
			//              1) хим. анализ террикона до изменения, или.
			//              2) хим. анализ террикона после изменения.
			//  Postfix - переменная отвечает за указание имени столбца таблицы "dt"
			//            в который будет осуществлена запись. 
			//            Значения: 
			//              1) "Before".
			//              2) "After".
			try
			{
				// Если все входные параметры переданы - выполняются дальнейшие действия.
				if (
					(dt != null && Chem != null && Postfix != null) &&
					(dt != null && Chem != "" && Postfix != "")
					)
				{
					// Флаг для использования в цикле.
					// Значения:
					//  n = 1 - элементу таблицы "dt" был найден идентичный (по id) эл. в хим анализе.
					//  n = 0 - элементу таблицы "dt" НЕ был найден идентичный (по id) эл. в хим анализе.
					int n = 0; 
					
					// Переменная для временного хранения элементов XML.
					XElement el = null;
	
					el = XElement.Parse(Chem);
	
					// Цикл по строкам таблицы "dt" (по хим. компонентам из вертикальной шапки). 
					foreach (DataRow dtRow in dt.Rows)
					{
						// Цикл по элементам анализа.
						foreach (var e in el.Elements())
						{
							n = 0; //Сброс флага.
	
							// Если элементу таблицы "dt" был найден идентичный (по id) 
							// эл. в хим анализе - выполняется запись
							// в поле таблицы "dt" в соответствии со значением 
							// входной переменной "Postfix":
							//  1) "cValueParametr" + Postfix = "cValueParametrBefore" либо 
							//  2) "cValueParametr" + Postfix = "cValueParametrAfter".
							if (Convert.ToInt32(dtRow["nParametrId"]) ==
								Convert.ToInt32(e.Element("nParametrId").Value))
							{
								dtRow["cValueParametr" + Postfix] = e.Element("cValueParametr").Value;
								n = 1;
								break;
							}
	
						}
						
						// Если для элемента в таблице "dt" НЕ был найден 
						// идентичный (по id) эл. в хим анализе - в таблицу "dt" записывается
						// пустое значение.
						if (n == 0)
							dtRow["cValueParametr" + Postfix] = "";
					}
				}
	
			} // end try
			catch (Exception ex)
			{
				// public class MessageBoxes from Itm.WClient.Com;
				MessageBoxes.Error(this, ex, "Ошибка наполнения временной таблицы информацией о хим. анализе террикона!");
				return;
			}
		}

            // Обработчик нажатия клавиш (общий для всех гридов).
            private void MyKeyDown(object sender, System.Windows.Forms.KeyEventArgs e)
            {
		try
		{
			Grid ig = (Grid)sender; // Получение ссылки на грид-источник.
			int nRowsCount = ig.Rows.Count; // Получение количества строк в гриде.

			Ctrl = false; // Сброс состояния статуса Ctrl.
			Shift = false; // Сброс состояния статуса Shift.
			Ctrl_CH = false;// Сброс состояния статуса Ctrl+C,H.

			// Фиксация факта нажатия клавиш Ctrl либо Shift в главном гриде.
			if (ig == igMain)
			{
				if (e.Control)
					Ctrl = true;
				
				if (e.Shift)
					Shift = true;
			}

			// Переменная "Ctrl_CH" фиксирует факт нажатия cочетания клавиш 
			// Ctrl+C, а затем H (Ctrl+C,H) в активном гриде.
			if (Ctrl_C = true // Если до этого вызова были нажаты клавиши Ctrl+C,
				&& e.KeyCode == Keys.H) // а в текущем клавиша "H", тогда 
							// выполняются дальнейшие действия.
			{
				if (nRowsCount > 0 // Если активный грид непустой
					&& ig.SelectedCells.Count > 0) // и в нём выделена хотя бы одна ячейка, тогда:
				{
					// 1) фиксируем факт нажатия клавиш Ctrl+C,H; 
					Ctrl_CH = true;
					// 2) вызываем метод копирования данных в буфер обмена.
					CopySelectedRowsToClipboard(sender, null);
					// 3) блокируем появление строки поиска по символу "h".
					ig.EnableQuickSearch = false;
				}
			}
			else // Если это не Ctrl+C,H разрешаем появление строки поиска.
			{
				if (ig.EnableQuickSearch == false)
					ig.EnableQuickSearch = true;
			}

			// Снятие выделения с ячеек и строк активного грида,
			// скрытие строки быстрого поиска.
			if (e.KeyCode == Keys.Escape)
			{
				ig.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
				ig.ClearSelection();
				
				ig.SelectionMode = DataGridViewSelectionMode.CellSelect;
				ig.ClearSelection();

				ig.EnableQuickSearch = false;
				ig.EnableQuickSearch = true;
			}

			// Переменная "Ctrl_C" фиксирует факт нажатия в активном гриде клавиш Ctrl+C.
			// Определяется в текущем событии.
			// Используется в методе "MyKeyPress"
			Ctrl_C = false;
			// Если нажато сочетание клавиш Ctrl+C
			if (e.Control && e.KeyCode == Keys.C)
			{
				// и в гриде есть хотя бы одна выделенная строка
				if (nRowsCount > 0)
				{
					// фиксируем факт нажатия клавиш Ctrl+C. 
					Ctrl_C = true;
					e.Handled = true;
				}
				else // Иначе, обрабатываем ошибку, возникающую при нажатии Ctrl+C в пустом гриде.
				{
					// Запрет события грида по умолчанию (предотвращение 
					// попытки копирования содержимого ячейки в буфер).
					e.Handled = true; 
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка обработчика нажатий клавиш клавиатуры!");
			return;
		}

            }

            // Обработчик нажатия клавиш следующий за "MyKeyDown".
            private void MyKeyPress(object sender, KeyPressEventArgs e)
            {
                Grid ig = (Grid)sender; // Получение ссылки на грид-источник.

                // Стандартное событие "KeyPress" следует после "KeyDown", минус заключается в том,
                // что текущее событие не поддерживает опрос нажатия нескольких клавиш, поэтому
                // факт нажатия обрабатывается в предыдущем событии("MyKeyDown"), а здесь 
                // выполняется опрос переменной "Ctrl_C". 
                if (Ctrl_C == true && ig.SelectedCells.Count > 0)
                {
                    // Вызов операции копирование выделенных строк грида в буфер обмена.
                    CopySelectedRowsToClipboard(sender, null);
                }
            }

            // Обработчик нажатия клавиш мыши (общий для всех гридов).
            private void MyMouseDown(object sender, MouseEventArgs e)
            {
		try
		{
			DataGridView dgv = (DataGridView)sender; // Получение ссылки на грид-источник.
			if (dgv.Rows.Count > 0) // Если грид непустой.
			{
				// Включение / отключение (при щелчке правой кнопкой мыши) активности 
				// пунктов контекстного меню (до его открытия).
				// Зависит от факта выбора значений пользователем.
				// Активируются / деактивируются пункты меню "Копировать" и "Копировать с заголовками".
				if (e.Button == MouseButtons.Right)
				{
					if (
						// Если это НЕ главный грид и в нём выбрана хотя бы одна ячейка
						(dgv != igMain && dgv.SelectedCells.Count > 0) ||
						// либо, грид главный, но ячейка выбрана за пределом первого столбца (заголовков строк).
						(dgv == igMain && dgv.CurrentCell.ColumnIndex > 0) ||
						// либо, грид главный и в нём выбрана хотя бы одна строка (для режима 
						// igMain.SelectionMode = FullRowSelect)
						(dgv == igMain && dgv.SelectedRows.Count > 0)
						)
					// тогда, активируем пункты контекстного меню грида-источника.
					{
						dgv.ContextMenuStrip.Items[8].Enabled = true;
						dgv.ContextMenuStrip.Items[9].Enabled = true;
					}
					else // Иначе деактивируем. 
					{
						dgv.ContextMenuStrip.Items[9].Enabled = false;
						dgv.ContextMenuStrip.Items[8].Enabled = false;
					}
				}

				// Перевод режима с 
				// igMain.SelectionMode = FullRowSelect на 
				// igMain.SelectionMode = CellSelect
				// при клике пользователем по ячейке вне пределов первого столбца (заголовка строк).
				if (e.Button == MouseButtons.Left && dgv == igMain)
				{
					MouseButtonsLeft = true;
					if (e.X > dgv.Columns[0].Width
						&& dgv.SelectionMode != DataGridViewSelectionMode.CellSelect)
					{
						dgv.SelectionMode = DataGridViewSelectionMode.CellSelect;
						// Сброс № столбца первой выбранной ячейки из группы выделенных до этого.
						// в последующем за текущим событием методе ("MyCellEnter") данное значение
						// будет установлено заново.
						nFirstSelectedCellsColumnIndex = -1; 
					}
				}

				// Если текущий грид-источник не главный – 
				// выполняется снятие выделения с ячеек и строк у всех 
				// вспомогательных гридов кроме текущего.
				if (e.Button == MouseButtons.Left && dgv != igMain)
				{
					GridsClearSelection(sender);
				}

			}
			// Отключение активности пунктов контекстного меню ("Копировать" и 
			// "Копировать с заголовками") если грид пустой.
			if (dgv.Rows.Count == 0)
			{
				dgv.ContextMenuStrip.Items[9].Enabled = false;
				dgv.ContextMenuStrip.Items[8].Enabled = false;
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка обработчика нажатий клавиш мыши!");
			return;
		}
            }

            // Обработчик события выбора ячейки.
            private void MyCellEnter(object sender, DataGridViewCellEventArgs e)
            {
		try
		{
			DataGridView dgv = (DataGridView)sender; // Получение ссылки на грид-источник.
			if (dgv.Rows.Count > 0 && dgv == igMain) // Если это главный грид и он не пустой.
			{
				int nRowIndex = 0;
				int nColumnIndex = 0;
				
				// Получаем координаты выбранной ячейки.
				nRowIndex = dgv.CurrentCell.RowIndex;
				nColumnIndex = dgv.CurrentCell.ColumnIndex;

				// Если это ни продолжение процесса выделения ячеек.
				if (nFirstSelectedCellsColumnIndex == -1)
				{
					// Сохраняем номер столбца первой выделенной ячейки.
					// Необходимо для определения, того, с кого столбца началось выделение значений.
					nFirstSelectedCellsColumnIndex = nColumnIndex;
				}

				// Если процесс выделения ячеек начался с первого столбца (заголовков строк), тогда
				if (nFirstSelectedCellsColumnIndex == 0)
				{
					// выполняем переключение режима на igMain.SelectionMode = FullRowSelect и
					if (dgv.SelectionMode != DataGridViewSelectionMode.FullRowSelect)
						dgv.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
					
					// выделяем каждую строку, ячейка которой попала в область выделения. 
					dgv.Rows[nRowIndex].Selected = true;
				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка выбора ячейки таблицы!");
			return;
		}
            }

            // Копирование выделенных строк грида в буфер обмена.
            private void CopySelectedRowsToClipboard(object sender, EventArgs e)
            {
                try
                {
                    ToolStripMenuItem tsmi = null;
                    DataGridView dgv = null;

                    bool goNext = false;
                    bool copyWithHeader = false;

                    // Определение грида источника (BEGIN).
                    
                    // Если текущий метод был вызван из "MyKeyPress" нажатием Ctrl+C значит источником
                    // будет грид - сохраняем ссылку на него в переменную "dgv".
                    if (sender is DataGridView)
                    {
                        dgv = (DataGridView)sender; // Получение ссылки на грид-источник.
                        copyWithHeader = Ctrl_CH; // Копируем с заголовками или без. 
                        goNext = true;
                    }

                    // Если текущий метод был вызван кликом по пункту "Копировать" в контестном меню
                    // значит источником будет контестное меню, поэтому получаем ссылку на грид из тэга
                    // (запись в тэг была осуществлена при создании данного пункта меню в "AlterHeapLog_Load"), 
                    // получив ссылку на грид так же помещаем её в переменную "dgv".
                    if (sender is ToolStripMenuItem)
                    {
                        tsmi = (ToolStripMenuItem)sender;
                        
                        // Определяем - копируем с заголовками или без.
                        if (tsmi.Name == "CopyWithHeader")
                            copyWithHeader = true;
                        else
                            copyWithHeader = false;

                        dgv = (DataGridView)tsmi.Tag; // Получение ссылки на грид-источник.
                        goNext = true;
                    }
                    // Определение грида источника (END).

                    // Если грид-источник идентифицирован - выполняются дальнейшие действия.
                    if (goNext)
                    {
                        // Количество видимых столбцов грида-источника.
                        int nVisibleColumnCount = 0;

                        // Счётчик видимых столбцов
                        int nVisibleColumn = 0;

                        // Текст копируемый в буфер обмена.
                        string st = "";
                        int nSelectedCellCount = 0;
                        
                        // Получаем список выделенных ячеек - со значениями и координатами.
                        DataGridViewSelectedCellCollection selectedCell = dgv.SelectedCells;

                        // Получаем количество выбранных ячеек. 
                        nSelectedCellCount = selectedCell.Count;

                        // Создание двумерного массива для хранения номера строки и столбца 
                        // каждой ячейки (с массивом проще работать).
                        int[,] selectedCellArray = new int[nSelectedCellCount,2];

                        // Наполнение массива координат.
                        for (int i = 0; i < nSelectedCellCount; i++)
                        {
                            int col = selectedCell[i].ColumnIndex;
                            int row = selectedCell[i].RowIndex;
                            
                            if (dgv.Columns[col].Visible)
                            {
                                //i - строки массива selectedCellArray.
                                selectedCellArray[i, 0] = col;
                                selectedCellArray[i, 1] = row;
                            }
                        }

                        // Если выбран режим копирования с заголовками – 
                        // формируем список названия полей для выбранных ячеек.
                        if (copyWithHeader == true)
                        {
                            // Подсчёт количества видимых столбцов грида-источника.
                            for (int j = 0; j < dgv.ColumnCount; j++)
                            if (dgv.Columns[j].Visible
                                && dgv.Columns[j].HeaderText != " "
                                && SelectedColumn(selectedCellArray, j)
                                )
                                nVisibleColumnCount += 1;
                            
                            // Копирование шапки грида-источника.
                            // Перебор в цикле всех видимых столбцов грида-источника и запись их
                            // текстовых названий в переменную "st".
                            // Название полей разделяются табуляцией, 
                            // после последнего столбца осуществляется перевод каретки.
                            
                            for (int j = 0; j < dgv.ColumnCount; j++)
                            if (dgv.Columns[j].Visible 
                                && dgv.Columns[j].HeaderText != " " // Если это не столбец заголовков сток.
                                && SelectedColumn(selectedCellArray, j) // Если в этом столбце есть хотя бы одна выбранная ячейка.
                                )
                            {

                                st += dgv.Columns[j].HeaderText;
                                if (nVisibleColumn < nVisibleColumnCount - 1)
                                    st += "\t";
                                else
                                    st += "\n";

                                nVisibleColumn += 1;
                            }
                        }

                        // Добавление данных к шапке.
                        // Перебор в цикле всех выделенных ячеек грида-источника в видимых столбцах и
                        // запись их содержимого в переменную "st".
                        // Ячейки разделяются табуляцией, 
                        // в конце каждой строки осуществляется перевод каретки.

                        int nRowCount = MyMaxCount(selectedCellArray, "Row");
                        int nColumnCount = MyMaxCount(selectedCellArray, "Column");
                        
                        string[,] myArray = new string[nRowCount, nColumnCount];

                        // Цикл по столбцам грида-источника.
                        for (int j = 0; j < nColumnCount; j++)
                        {
                        // Цикл по строкам грида-источника.
                            for (int i = 0; i < nRowCount; i++)
                            {
                                // Если ячейка выбрана и столбец является видимым (не скрытый).
                                if (
                                    dgv[j, i].Selected
                                    && dgv.Columns[j].Visible
                                    && dgv.Columns[j].HeaderText != " "
                                    )
                                    if (selectedCellArray.GetLength(0) != 1)
                                    {
                                        if (j < nColumnCount - 1)
                                            myArray[i, j] = dgv[j, i].Value.ToString() + "\t";
                                        else
                                            myArray[i, j] = dgv[j, i].Value.ToString() + "\n";

                                    }
                                    else // Если это самая последняя из выбранных ячеек,
                                         // знаки табуляции не приклеиваем.
                                         // Потому что, если содержимое такой ячейки из буфера 
                                         // вставить в фильтр заголовков он ничего не найдёт 
                                         // из-за прилепленного знака табуляции,
                                         // по этому, последнюю ячейку копируем "как есть".
                                        myArray[i, j] = dgv[j, i].Value.ToString();

                                // Вместо невыбранных ячеек ставим только знаки табуляции.
                                if (
                                    !dgv[j, i].Selected
                                    && dgv.Columns[j].Visible
                                    && dgv.Columns[j].HeaderText != " "
                                    )
                                    if (j < nColumnCount - 1)
                                        myArray[i, j] = "\t";
                                    else
                                        myArray[i, j] = "\n";
                            }
                        }

                        for (int i = 0; i < nRowCount; i++) // Цикл по строкам грида-источника.
                        for (int j = 0; j < nColumnCount; j++)// Цикл по столбцам грида-источника.
                        // Помещаем полученный результат в переменную "st".
                        if (
                            dgv.Columns[j].Visible
                            && dgv.Columns[j].HeaderText != " "
                            && SelectedColumn(selectedCellArray, j)
                            && SelectedRow(selectedCellArray, i)
                            )
                            st += myArray[i, j];
                        
                        // Снятие блокировки буфера обмена.
                        // Предотвращение сбойной ситуации при попытке записи 
                        // в заблокированный буфер обмена, занятый текущим или 
                        // каким-либо другим приложением.
                        CloseClipboard();

                        // Копирование содержимого выделенных ячеек (с установленной табуляцией)
                        // в буфер обмена.
                        Clipboard.SetText(st);

                    }

                } // end try
                catch
                {
                    string caption = "Ошибка при работе с буфером обмена.";
                    string message = "Ошибка копирования выделенного текста в буфер обмена.\n" +
                                     "Копирования не произошло. Повторите попытку ещё раз.";

                    MessageBox.Show(message, caption,
                                    MessageBoxButtons.OK,
                                    MessageBoxIcon.Error);
                }
            }

            // Метод проверки столбца с номером nColumnIndex на наличие хотя бы одной выделенной ячейки.
            private static bool SelectedColumn(int[,] nArray, int nColumnIndex)
            {
                bool res = false;

                for (int i = 0; i < nArray.GetLength(0); i++)
                {
                    if (nArray[i,0] == nColumnIndex)
                    {
                        res = true;
                        break;
                    }
                }
                return res;
            }

            // Метод проверки строки с номером nRowIndex на наличие хотя бы одной выделенной ячейки.
            private static bool SelectedRow(int[,] nArray, int nRowIndex)
            {
                bool res = false;

                for (int i = 0; i < nArray.GetLength(0); i++)
                {
                    if (nArray[i, 1] == nRowIndex)
                    {
                        res = true;
                        break;
                    }
                }
                return res;
            }
            
            // Метод рассчитывает координаты самой последней ячейки из выбранного диапазона.
            // Необходимо для получения размерности циклов по строкам и столбцам грида-источника.
            // Получение ColCount и RowCount для циклов в "CopySelectedRowsToClipboard".
            private static int MyMaxCount(int[,] nArray, string nFieldType)
            {
                int max = 0;
		int length = nArray.GetLength(0);
		
		try
		{	
			if (length > 0)
			{
				// Получение ColCount для диапазона выбранных ячеек.
				if (nFieldType == "Column")
				{
					max = nArray[0, 0];
					for (int i = 1; i < length; i++)
					{
						if (nArray[i, 0] > max)
							max = nArray[i, 0];
					}
				}

				// Получение RowCount для диапазона выбранных ячеек.
				if (nFieldType == "Row")
				{
					max = nArray[0, 1];
					for (int i = 1; i < length; i++)
					{
						if (nArray[i, 1] > max)
							max = nArray[i, 1];
					}

				}
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка расчёта координат последней ячейки из выбранного диапазона!");
			return;
		}
                return max+1;
            }

            // Метод выполняет снятие выделения с ячеек и строк у всех второстепенных 
            // гридов, кроме грида источника.
            public void GridsClearSelection(object sender)
            {
                try
		{	
			DataGridView dgv = (DataGridView)sender; // Получение ссылки на грид-источник.

			// Первым решением был рекурсивный перебор компонентов Control’а - источника
			// и снятие выделения у всех объектов с типом Grid, но такое решение
			// было не оптимальным с точки зрения производительности, да и список гридов –
			// константное значение, поэтому указал напрямую у какого грида и при каких условиях 
			// снимать выделение строк и ячеек.

			switch (dgv.Name)
			{
				case "igHeapParameters":
					igValueProbeBefore.ClearSelection();
					igValueProbeAfter.ClearSelection();
					break;

				case "igValueProbeBefore":
					igHeapParameters.ClearSelection();
					igValueProbeAfter.ClearSelection();

					break;
				case "igValueProbeAfter":
					igHeapParameters.ClearSelection();
					igValueProbeBefore.ClearSelection();
					break;
			}
		}
		catch (Exception ex)
		{
			// public class MessageBoxes from Itm.WClient.Com;
			MessageBoxes.Error(this, ex, "Ошибка сброса выделения ячеек таблиц!");
			return;
		}
            }

        #endregion Private Methods

    }
}

