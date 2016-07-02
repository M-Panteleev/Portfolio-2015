// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace Itm.WClient.FactoryServices.StoredReports
{
    /// <summary>
    /// Окно редактирования данных.
    /// Предоставляет доступ к редактированию данных отчёта. 
    /// </summary>
    /// <remarks>
    /// Автор: Родшелев С.А.   
    /// Ред.: 		     Пантелеев М.Ю. Пантелеев М.Ю. 
    /// Дата: 		     09.06.2015г.   01.07.2015г.
    /// </remarks>
    public partial class ReportDataDialog : Form
    {
        #region Constructor

            public ReportDataDialog()
            {
                InitializeComponent();
            }

        #endregion Constructor

        #region Public Properties

            /// <summary>
            /// Данные для редактирования.
            /// Нельзя назначить напрямую, так как неправильно обработается в гриде.
            /// </summary>
            public DataTable Source { get; set; }

            /// <summary>
            /// Данные для построения столбцов
            /// </summary>
            public IEnumerable<EditableFieldInformation> Captions { get; set; }

            /// <summary>
            /// Уникальное наименование Id строк таблицы
            /// </summary>
            public string PrivaryKeyName
            {
                get { return igMain.IDColumn; }
                set { igMain.IDColumn = value; }
            }

            /// <summary>
            /// Изменённые пользователем данные
            /// </summary>
            public IEnumerable<EditedInformation> EditedData
            {
                get { return edited; }
            }
            // Добавил: Пантелеев М.Ю.
            // Дата:    09.06.2015г.
            // Добавлены 3-и дополнительных параметра отчёта: "UserName", "UpdateEqualValue", "NameFieldGroup".
             
            /// <summary>
            /// ФИО текущего пользователя
            /// </summary>
            public string UserName { get; set; }
           
            /// <summary>
            /// Флаг обновления идентичных значений записей состоящих в одной группе с изменяемой.
            /// Группа определяется по параметру "NameFieldGroup".
            /// </summary>
            public bool UpdateEqualValue { get; set; }

            /// <summary>
            /// Название числового поля, по которому определяется группа.
            /// Записи, имеющие одинаковое значение в данном поле, будут считаться состоящими в группе.
            /// </summary> 
            /// <remarks>
            /// Если флаг "UpdateEqualValue" = true, значит при изменении одного из значений группы 
            /// будет выполнено автоматическое изменение значений для всех записей состоящих в группе. 
            /// Автоматическое изменение значений будет выполнено в том же столбце, в котором 
            /// было выполнено редактирование первой измененяемой ячейки.
            /// Необходимо в ситуации, когда ХП отчёта возвращает рекордсет, у записей которого 
            /// содержимое одного из редактируемых полей совпадает (например, записи различаются по содержимому, но 
	    /// имеют одинаковое итоговое значение), 
	    ///	при редактировании данных такого отчёта пользователю не ясно для какой записи выполнить изменение итога,
            /// чтобы потом, это изменённое значение отобразилось в отчёте. 
	    /// Данное поле совместно с флагом "UpdateEqualValue" активирует функционал 
            /// автоматического изменения всех записей с одним и тем же итогом, что в свою очередь 
            /// позволяет исключить неоднозначность, т.к. пользователю больше не требуется 
            /// изменять строку за строкой и потом смотреть отобразилось отредактированное значение в отчёте
            /// или нет.
            /// </remarks>
            public string NameFieldGroup { get; set; }

        #endregion Public Properties

        #region Events Handlers

            private void ReportDataDialog_Load(object sender, EventArgs e)
            {
                if (!DesignMode) { Init(); }
            }

            private void btnOK_Click(object sender, EventArgs e)
            {
                Source = igMain.DataSource as DataTable;
                DialogResult = DialogResult.OK;
            }
            
	    // Добавил: Пантелеев М.Ю.
            // Дата: 	10.06.2015г.
	    // Контроль разрядности вещественных чисел.
	    // Проверка выполняется "на лету" - в момент ввода данных с клавиатуры или из буфера обмена. 
            private void igMain_CellValidating(object sender, DataGridViewCellValidatingEventArgs e)
            {
                // Получаем тип данных поля редактируемой ячейки.
                Type type = igMain.Columns[igMain.CurrentCell.ColumnIndex].ValueType;

                // Если поле, в котором редактируется ячейка, не является строковым.
                if (igMain[e.ColumnIndex, e.RowIndex].IsInEditMode && type != typeof(string))
                {
                    bool isBlock = false;
                    string str = e.FormattedValue.ToString();
                    decimal f = 0;
                    int i = 0;
                    
                    // Выполняем парсинг разделителя и сохраняем результат во временную переменную.
                    str = (str ?? string.Empty).ToString().Replace(",", dot).Replace(".", dot);

                    // Если не пусто, но во время парсинга возникли ошибки
                    if (!string.IsNullOrEmpty(str)) 
                    {
                        // Если во время парсинга возникли ошибки
                        if (
                                (type == typeof(decimal) && !decimal.TryParse(str, out f)) ||
                                (type == typeof(int) && !int.TryParse(str, out i))
                           ) 
                            isBlock = true; // устанавливаем статус блокировки.
                    } 

                    // Получаем позицию разделителя.
                    int pos = str.IndexOf(',');
                    
                    // Ред.: Пантелеев М.Ю.
                    // Дата: 29.06.2015г.
                    // Отмена редактирования если целая часть десятичного числа 
                    // содержит больше 6-и символов, либо, введено число без запятой, но его длинна
                    // превышает 6 символов.
                    // Необходимо для обработки ошибки переполнения, возникающей при попытке
                    // записи десятичного числа превышающего принятую в БД разрядность - decimal(9,3).
                    if (
                            (isBlock == true) || // Если во время парсинга возникли ошибки.
                                                 // или 
                            (                    
                                (type == typeof(decimal)) && // поле в БД имеет десятичный тип

                                (    // и при этом:
                                    (pos > 6) || // целая часть введённого числа содержит больше 6-и символов
                                    ((pos <= 0) && (str.Length > 6)) //либо, введено число без запятой, но его длинна превышает 6 символов
                                )
                            )
                       )
                        // отменяем редактирование.
                        igMain.CancelEdit();
                    else
                    {   // Иначе, сохраняем результат парсинга в ячейку.

                        // Если у числа есть десятичная часть
                        if ((pos > 0) && (str.Length > pos + 4))
                        {
                            // Отмеряем три знака после запятой.
                            int startPos = pos + 4;
                            // Удаляем всё лишнее после трёх знаков.
                            str = str.Remove(startPos, str.Length - startPos);
                        }
                        // сохраняем результат парсинга в ячейку.
                        tb.Text = str;
                        // Переменная "tb" содержит редактируемую ячейку грида. 
                        // Инициируется во время начала редактирования ячейки (в событии "igMain_EditingControlShowing").
                    }
                }
            }
           
            private void igMain_CellParsing(object sender, DataGridViewCellParsingEventArgs e)
            {
                try
                {
                    if (igMain.SelectedDataRow != null)
                    {
                        // Автор: Пантелеев М.Ю.
                        // Дата: 10.06.2015г.
                        // Добавление изменяемых значений в список обновляемых(в таблице SQL сервера) 
                        // и обновление значений в гриде.
                        UpdateValues(e.RowIndex, e.ColumnIndex, e.Value, igMain.SelectedRowID);
                        
                        e.ParsingApplied = true;
                    }
                }
                catch (FormatException)
                {
                    e.ParsingApplied = false;
                }
            }
            

            private void igMain_CellFormatting(object sender, DataGridViewCellFormattingEventArgs e)
            {
                // Изменил: Пантелеев М.Ю.
                // Дата: 09.06.2015г.
                // Закомментировал участок ниже т.к. "new DataGridViewCellStyle()" 
                // сбрасывает настройки столбцов грида(выравнивание, ширину и т.д.).
                
                //раскрасим редактируемые ячейки в светло-зелёный цвет
                //if (igMain.Columns[e.ColumnIndex].ReadOnly)
                //    e.CellStyle = new DataGridViewCellStyle() 
                //        {
                //            BackColor = Color.LightGray, 
                //            Font = e.CellStyle.Font 
                //        };
            }
			
	    // Добавил: Пантелеев М.Ю.
            // Дата: 10.06.2015г.
            private void igMain_EditingControlShowing(object sender, DataGridViewEditingControlShowingEventArgs e)
            {
                // Получаем тип данных редактируемой ячейки.
                Type type = igMain.Columns[igMain.CurrentCell.ColumnIndex].ValueType;

                if (e.Control is TextBox && type != typeof(string))
                {
                    // Представляем ячейку в качестве объекта "TextBox" для работы с его свойствами.
                    tb = (TextBox)e.Control;
                    // Подписываемся на событие нажатия клавиши.
                    tb.KeyPress += new KeyPressEventHandler(tb_KeyPress);
                }
            }
			
	    // Автор: Пантелеев М.Ю.
            // Дата: 10.06.2015г.
            /// <summary>
            /// Парсинг разделителя при вводе с клавиатуры. Проверка значения введённого пользователем.
            /// </summary>
            /// <remarks>
            /// Ред.: Пантелеев М.Ю.
            /// Дата: 30.06.2015г.
            /// </remarks>
            private void tb_KeyPress(object sender, KeyPressEventArgs e)
            {
                if ((e.KeyChar == '.') || (e.KeyChar == ','))
                {
                    e.KeyChar = dot[0];
                }

                // Добавил: Пантелеев М.Ю.
                // Дата: 30.06.2015г.
                // Обработка ошибки возникающей при попытке сохранения в БД десятичного числа, 
                // значение которого, превышает формат базы decimal(9,3).
                //
                // Получаем тип данных редактируемой ячейки.
                Type type = igMain.Columns[igMain.CurrentCell.ColumnIndex].ValueType;
                // Если поле, в котором редактируется ячейка, не является строковым.
                if (type != typeof(string))
                {
                    // Представляем ячейку в качестве объекта "TextBox" для работы с его свойствами.
                    tb = (TextBox)sender;

                    // Текст ячейки без учёта нажатого символа(с парсингом разделителя). 
                    string str = (tb.Text ?? string.Empty).ToString().Replace(",", dot).Replace(".", dot); ;

                    // Блокируем нажатие, если это
                    if (
                            (e.KeyChar != (char)8)  && // не backspace
                            (e.KeyChar != (char)22) && // не Сtrl+V
                            (e.KeyChar != (char)24) && // не Сtrl+X
                            (e.KeyChar != (char)44) && // не запятая
                            (e.KeyChar <'0' || e.KeyChar >'9') //, а буква или спец. символ
                       )
                        e.Handled = true; // блокируем нажатие.

                    // Блокируем нажатие запятой если в тексте уже есть запятая.
                    if ((e.KeyChar == (char)44) && (str.IndexOf(',') != -1))
                        e.Handled = true;

                    // Если
                    if (type == typeof(decimal) && // поле предназначено для хранения десятичных чисел
                        e.Handled == false)        // и введённый символ является числом 
                    // выполняем проверку.
                    {
                        // Текущая позиция каретки.
                        int selPos = tb.SelectionStart;
                        // Количество выделенных символов в тексте ячейки.
                        int selLen = tb.SelectionLength;
                        // Получаем текст ячейки с учётом нажатого символа.
                        str = str.Insert(selPos, e.KeyChar.ToString());
                        // Позиция разделителя.
                        int pos = str.IndexOf(',');

                        // Если
                        if (    (e.KeyChar != (char)8) && // это не backspace
                                (selLen == 0) && // ни один символ не выделен (на место которого можно было бы вставить из буфера)
                                (
                                    (pos > 6) || // и целая часть введённого числа содержит больше 6-и символов
                                    ((pos <= 0) && (str.Length > 6)) //либо, введено число без запятой, но его длинна превышает 6 символов
                                 )
                            )
                        // тогда, блокируем нажатие.
                        e.Handled = true;
                    }
                }
            }

        #endregion Events Handlers


        #region Private Methods

            private void Init()
            {
                //построение столбцов грида
                List<DataGridViewTextBoxColumn> cols = new List<DataGridViewTextBoxColumn>();
                foreach (var data in Captions)
                {
                    // Добавил: Пантелеев М.Ю.
                    // Дата: 09.06.2015г.
                    // BTS: ****.
		    // Добавлено: 
		    // 1) выравнивание содержимого столбцов по левому краю;
		    // 2) окрашивание полей "только для чтения" в неактивный серый цвет;
		    // 3) добавление автоизменяемых полей в специальный список(см. "AutoEditedList").
                    var col = GetNewColumn(data);
                    
                    // 1) Выравнивание содержимого столбца по левому краю.
                    col.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleLeft;
                    
                    // 2) Если столбец "только для чтения" красим его в серый цвет.
                    if (data.ReadOnly == true) col.DefaultCellStyle.BackColor = Color.LightGray;
                    
                    // 3) Если столбец автоизменяемый добавляем его в соответствующий список.
                    if (data.TypeContent.ToString() != "0")
                        AutoEditedList.Add(new AutoEditedFields()
                        {
                            DataFieldName = data.DataFieldName, // Наименование столбца.
                            TypeContent = data.TypeContent      // Свойство.
                        });
                                    
                    cols.Add(col);
                }
                //последний столбец надо растянуть
                cols.Last().AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill;

                igMain.Columns.AddRange(cols.ToArray());

                igMain.DataSource = Source;
            }

            private DataGridViewTextBoxColumn GetNewColumn(EditableFieldInformation data)
            {
                return new DataGridViewTextBoxColumn(){
                    DataPropertyName = data.DataFieldName,
                    HeaderText = data.HeaderText,
                    Name = data.DataFieldName,
                    ReadOnly = data.ReadOnly,
                    // Добавил: Пантелеев М.Ю.
                    // Дата: 09.06.2015г.
                    // BTS: ****.
		    // Если значения параметров поля не были переданы, свойства устанавливаются по умолчанию. 
                    Width = data.Width ?? 80,
                    MinimumWidth = data.MinimumWidth ?? 25,
                    SortMode = DataGridViewColumnSortMode.NotSortable,
                    AutoSizeMode = data.SizeMode
                };
            }
			
	    // Автор: Пантелеев М.Ю.
            // Дата: 09.06.2015г.
            /// <summary>
            /// Добавление изменяемых значений в список обновляемых(в таблице SQL сервера)
            /// и обновление значений в гриде.
            /// </summary>
            /// <remarks>
            /// Ред.: Пантелеев М.Ю.
            /// Дата: 10.06.2015г.
            /// </remarks>
            private void UpdateValues(int RowIndexIn, int ColumnIndexIn, object ValueIn, int SelectedRowIDIn)
            {
                try
                {
                    // Получаем текущую дату в местном часовом поясе.
                    DateTime dDateNow = DateTime.Now;

                    // Добавляем изменённые значения в список 
                    // обновляемых (в таблице SQL сервера) и обновляем в гриде.
                    EditedCellsAdd(RowIndexIn, ColumnIndexIn, ValueIn, SelectedRowIDIn, dDateNow);

                    // Если требуется выполнять обновление записей с идентичным значением
                    // Автоматическое изменение значений будет выполнено в том же столбце,
                    // в котором было выполнено редактирование первой измененяемой ячейки.
                    // Необходимо в ситуации, когда ХП отчёта возвращает рекордсет, 
                    // у каждой записи которого отображается один и тот же итог, 
                    // при редактировании данных такого отчёта пользователю не ясно 
                    // для какой записи выполнить изменение итога, что бы потом это изменённое значение 
                    // отобразилось в отчёте.
                    // Автоматическое изменение всех записей с одним и тем же итогом 
                    // позволяет исключить неоднозначность, т.к. пользователю больше не требуется 
                    // изменять строку за строкой и потом смотреть отобразилось отредактированное 
                    // значение в отчёте или нет.
                    if ((UpdateEqualValue = true)&&
                        (NameFieldGroup != null))
                    {
                        // Здесь будет ID группы строк, в которой состоит отредактированная запись.
                        int? GroupID = null;

                        // Получаем ID записи (значение из поля "igMain.IDColumn")
                        int nID = igMain.SelectedRowID;

                        // Определяем, к какой группе относится отредактированная запись.
                        foreach (DataRow row in Source.Rows)
                        {
                            if (row.Field<int>(igMain.IDColumn) == igMain.SelectedRowID)
                            {
                                GroupID = row.Field<int>(NameFieldGroup);
                                break;
                            }
                        }

                        // Если группа определена выполняем обновление записей.
                        if (GroupID != null)
                        {
                            // Здесь будет список идентификаторов строк состоящих в группе.
                            List<int> lst = new List<int>();

                            // Получаем список идентификаторов строк состоящих в группе.
                            foreach (DataRow row in Source.Rows)
                            {
                                if ((row.Field<int>("nMaterialId") == GroupID) &&
                                   (row.Field<int>("nMaterialId") != nID))
                                {
                                    lst.Add(row.Field<int>(igMain.IDColumn));
                                }
                            }

                            // Цикл по списку идентификаторов строк.
                            for (int i = 0; i < lst.Count; i++)
                            {
                                // Цикл по строкам грида.
                                for (int j = 0; j < igMain.RowCount; j++)
                                {
                                    igMain.ClearSelection();
                                    igMain.Rows[j].Selected = true;

                                    // Если ID строк совпали
                                    if (igMain.SelectedRowID == lst[i])
                                    {
                                        // Добавляем изменённые значения в список 
                                        // обновляемых (в таблице SQL сервера) и обновляем в гриде.
                                        EditedCellsAdd(j, ColumnIndexIn, ValueIn, igMain.SelectedRowID, dDateNow);
                                        break;
                                    }
                                }
                            }
                            igMain.ClearSelection();
                        }
                    }
                }
                catch (FormatException)
                {
                   
                }
            }
        
            // Автор: Пантелеев М.Ю.
            // Дата: 10.06.2015г.
            /// <summary>
            /// Запись значения в грид и обновление (если требуется) автоизменяемых полей 
            /// с датой последнего изменения и ФИО пользователя внёсшего изменения.
            /// </summary>
            /// <remarks>
            /// Автор: Пантелеев М.Ю.
            /// Дата: 10.06.2015г.
            /// </remarks>
            private void EditedCellsAdd(int RowIndexIn, int ColumnIndexIn, object ValueIn, int SelectedRowIDIn, DateTime dDateNowIn)
            {

                if (ValueIn.ToString() == "")
                    ValueIn = null;
                
                // Добавляем значение введёное пользователем в список обновляемых(в таблице SQL сервера).
                edited.Add(new EditedInformation()
                {
                    Id = SelectedRowIDIn,
                    DataFieldName = igMain.Columns[ColumnIndexIn].DataPropertyName,
                    Value = ValueIn
                });

                // Обновляем ячейку в гриде.
                igMain.Rows[RowIndexIn].Cells[ColumnIndexIn].Value = ValueIn ?? DBNull.Value;
                
                // Если необходимо изменить содержимое автоизменяемых полей – делаем это.    
                if (AutoEditedList != null)
                {
                    // Здесь будет либо текущая дата, либо ФИО пользователя внёсшего изменения.
                    object OverallValue = null;
                    
                    // Цикл по списку автоизменяемых полей.
                    foreach (AutoEditedFields el in AutoEditedList)
                    {
                        if (ValueIn != null)
                        {
                            if (el.TypeContent == TypeContent.DateEdit) { OverallValue = dDateNowIn; }
                            if (el.TypeContent == TypeContent.UserName) { OverallValue = UserName; }
                        } // Иначе, если ValueIn = null - происходит очищение автозаполняемых полей
                        
                        // Добавляем значение автоизменяемой ячейки
                        // в список обновляемых(в таблице SQL сервера).
                        edited.Add(new EditedInformation()
                        {
                            Id = SelectedRowIDIn,
                            DataFieldName = el.DataFieldName,
                            Value = OverallValue
                        });
                        // Обновляем ячейку в гриде.
                        igMain.Rows[RowIndexIn].Cells[el.DataFieldName].Value = OverallValue ?? DBNull.Value;

                    }
                }
            }

        #endregion Private Methods

        #region Private Members

                string dot = System.Globalization.CultureInfo.CurrentCulture.NumberFormat.NumberDecimalSeparator;

                // Список редактированных данных.
                List<EditedInformation> edited = new List<EditedInformation>();

                // Добавил: Пантелеев М.Ю.
                // Дата: 10.06.2015г.        
                // Список названий автоизменяемых полей.
                // Содержимое ячеек в данных столбцах будет изменяться автоматически 
                // при редактировании других ячеек строки грида.
                List<AutoEditedFields> AutoEditedList = new List<AutoEditedFields>();

		// Добавил: Пантелеев М.Ю.
                // Дата: 10.06.2015г.   
                /// <summary>
                /// Содержит редактируемую ячейку грида. Инициируется в событии 
                /// "igMain_EditingControlShowing"(во время начала редактирования ячейки).
                /// </summary>
                /// <remarks>
                /// Используется для доступа к свойствам ячейки как объекта "TextBox".
                /// </remarks>
                TextBox tb;

        #endregion Private Members

    }
}

