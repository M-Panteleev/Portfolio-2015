// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Forms;
using System.Drawing;
using System.Data;
using Itm.AccessDB;
using Itm.WClient.Com;
using Itm.WControls;

namespace Itm.WClient.FactoryServices.StoredReports
{
    /// <summary>
    /// Общий класс для отчётов, которые хранят своё состояние ( а не используют оперативные данные)
    /// </summary>
    /// Автор: Родшелев С.А.
    /// Ред.:               Пантелеев М.Ю.
    /// Дата:               09.06.2015г.
    public abstract class PlantStoredReports : Reporting.BaseReportControl, IUserTimeZone
    {
        #region Constructor

            protected PlantStoredReports()
            {
                RefreshOnStart = false;
                ShowWaitOnFill = true;

                SqlProc.CommandTimeout = 120;

                // добавление процедур по трем составляющим:
                // 1) ключ процедуры (синионим), 2) название процедуры в Sql-сервере без схемы, 
                // 3) назначение процедуры (v-чтение, e-редактирование)
                spc.AddProc(
                    "AlterReportTableParametrs", "AlterReportTableParametrs", "e",
                    "GetCurUsers", "GetCurUsers", "v"
                    );
            }

        #endregion Constructor

        #region IUserTimeZone Members

            public TimeZoneInfo UserTimeZone { get; set; }

        #endregion

        #region Protected Methods

            protected override void FillReportFilters()
            {
                switch (Interval)
                {
                    case ReportIntervals.Day :
                        SetDailyInterval();
                        break;
                    case ReportIntervals.Month :
                        SetMonthlyInterval();
                        break;
                    case ReportIntervals.None :
                        SetNoneInterval();
                        break;
                    case ReportIntervals.Standard:
                        break;
                    default:
                        throw new NotImplementedException("Невозможно построить фильтр для выбранного интервала времени отчёта.");
                }

                //только для отчётов, позволяющих редактирование
                if (EnableEdit)
                {
                    tsbEdit = new ToolStripButton {
                        Image = toolReport.btnEdit.Image,
                        Text = @"Редактировать",
                        TextImageRelation = TextImageRelation.ImageBeforeText,
                        Margin = new Padding(5, Margin.Top, Margin.Right, Margin.Bottom)
                    };

                    tsbEdit.Click += EditButton_Click;

                    toolReport.Items.Add(tsbEdit);

                    //если передано несколько источников данных, то надо сформировать меню выбора для редактирования
                    if (EditedInfoList != null && EditedInfoList.Any())
                    {
                        editMenu = new ContextMenuStrip();

                        foreach (var info in EditedInfoList)
                        {
                            var item = new ToolStripMenuItem {Text = info.Caption};
                            item.Click += EditMenu_Click;
                            editMenu.Items.Add(item);
                        }
                    }
                }

                //Если необходимо добавить фильтр по шихтовым материалам.
                if (RequiredBurdenMaterialFilter)
                {
                    try
                    {
                        var dt = spc.FillTable("GetMaterial",
                            "nMaterialGroupIdIn", -1, SqlDbType.Int);

                        var row = dt.NewRow();
                        row["nMaterialId"] = DBNull.Value;
                        row["cNameMaterial"] = "- Все -";
                        dt.Rows.InsertAt(row, 0);

                        tscbMaterials = new ToolStripComboBox();
                        tscbMaterials.Size = new Size(200, tscbMaterials.Height);
                        tscbMaterials.DropDownWidth = 300;
                        if (tscbMaterials.ComboBox != null)
                        {
                            tscbMaterials.ComboBox.DisplayMember = "cNameMaterial";
                            tscbMaterials.ComboBox.ValueMember = "nMaterialId";
                            tscbMaterials.ComboBox.DataSource = dt;
                        }

                        tscbMaterials.SelectedIndexChanged += (o, e) => FillReport();

                        toolReport.Items.Add(new ToolStripSeparator());
                        toolReport.Items.Add(new ToolStripLabel("Материал:"));
                        toolReport.Items.Add(tscbMaterials);
                    }
                    catch (Exception ex)
                    {
                        MessageBoxes.Error(this, ex, "Ошибка получения списка материалов фильтра.");
                    }
                }

                //Загружаем данные о текущем пользователе.
                LoadUserData();
            }

            #endregion Protected Methods

            #region Protected Members

            /// <summary>
            /// Тип интервала отчёта
            /// </summary>
            protected ReportIntervals Interval = ReportIntervals.None;

            /// <summary>
            /// Флаг возможности редактирования данных отчёта.
            /// </summary>
            protected bool EnableEdit = true;

            /// <summary>
            /// Флаг необходимости отображения фильтра по шихтовым материалам
            /// </summary>
            protected bool RequiredBurdenMaterialFilter = false;

            /// <summary>
            /// Дата начала интервала отчёта (локальная)
            /// </summary>
            protected DateTime? BeginInterval
            {
                get { return toolReport.StartDateLocal; }
            }

            /// <summary>
            /// Дата окончания интервала отчёта (локальная)
            /// </summary>
            protected DateTime? EndInterval
            {
                get { return toolReport.EndDateLocal; }
            }

            /// <summary>
            /// Список данных для редактирования отчёта.
            /// Для каждого источника, данные которого необходимо редактировать нужно заполнить все поля.
            /// </summary>
            protected IEnumerable<SourceInformation> EditedInfoList { get; set; }

            /// <summary>
            /// ФИО текущего пользователя.
            /// </summary>
            protected string UserName = "- нет данных -";

            /// <summary>
            /// Логин текущего пользователя.
            /// </summary>
            protected string UserLogin = "- нет данных -";

            /// <summary>
            /// Возвращает Id выбранного материала, если активен фильтр по шихтовым материалам
            /// </summary>
            protected int? SelectedBurdenMaterialId
            {
                get
                {
                    int? res = null;

                    if (tscbMaterials != null)
                        if (tscbMaterials.ComboBox != null) res = tscbMaterials.ComboBox.SelectedValue as int?;

                    return res;
                }
            }

            // Добавил: Пантелеев М.Ю.
            // Дата:    09.06.2015г.
            // Добавлены 2-а параметра отчёта: "UpdateEqualValue", "NameFieldGroup".
             
            /// <summary>
            /// Флаг обновления идентичных значений состоящих в одной группе с изменяемым.
            /// Группа определяется по параметру "NameFieldGroup".
            /// </summary>
            public bool UpdateEqualValue { get; set; }

            /// <summary>
            /// Название числового поля, по которому определяется группа.
            /// Записи, имеющие одинаковое значение в данном поле, будут считаться состоящими в группе.
            /// </summary> 
            /// <remarks>
            /// Если флаг "UpdateEqualValue" = true, значит в окне редактирования отчёта 
            /// при изменении одного из значений группы будет выполнено автоматическое изменение значений 
            /// для всех записей состоящих в группе. Автоматическое изменение значений будет выполнено 
            /// в том же столбце, в котором было выполнено редактирование первой измененяемой ячейки.
            /// Необходимо в ситуации, когда ХП отчёта возвращает рекордсет, у каждой записи которого 
            /// отображается один и тот же итог,  при редактировании данных такого отчёта пользователю 
            /// не ясно для какой записи выполнить изменение итога, что бы потом это изменённое значение 
            /// отобразилось в отчёте. Данное поле совместно с флагом "UpdateEqualValue" активирует функционал 
            /// автоматического изменения всех записей с одним и тем же итогом, что в свою очередь 
            /// позволяет исключить неоднозначность, т.к. пользователю больше не требуется 
            /// изменять строку за строкой и потом смотреть отобразилось отредактированное значение в отчёте
            /// или нет.
            /// </remarks>
            public string NameFieldGroup { get; set; }


        #endregion Protected Members

        #region Events Handlers

        private void EditButton_Click(object sender, EventArgs e)
        {
            //Если один источник данных, то показываем форму с редактированием, 
            //если же их несколько, то надо показать меню с возможностью выбора
            //источника данных для редактирования
            if (EditedInfoList == null || !EditedInfoList.Any())
                throw new NullReferenceException("Не переданы данные для редактирования отчёта");
            if (EditedInfoList.Count() == 1)
                Edit(EditedInfoList.First());
            else
                ShowMenu();
        }

        private void EditMenu_Click(object sender, EventArgs e)
        {
            var item = sender as ToolStripMenuItem;

            if (item != null)
            {
                var info = EditedInfoList.First(i => i.Caption == item.Text);
                Edit(info);
            }
        }

        #endregion Events Handlers

        #region Private Methods

        private void SetDailyInterval()
        {
            //Для ежедневного отчёта выставим в ItmToolStrip "Заданные сутки"

            var cln = toolReport.btnDateFilter.DropDown.Items;
            foreach (var key in cln.OfType<ToolStripItem>().Select(item => item.Name).ToList().Where(key => !key.Equals("tsmCustomDay")))
                cln.RemoveByKey(key);

            toolReport.SelectedInterval = ItmToolStrip.DateInterval.CustomDay;
        }

        private void SetMonthlyInterval()
        {
            //Для ежедневного отчёта выставим в ItmToolStrip "Заданный месяц"

            var cln = toolReport.btnDateFilter.DropDown.Items;
            foreach (var key in cln.OfType<ToolStripItem>().Select(item => item.Name).ToList().Where(key => !key.Equals("tsmCustomMonth")))
                cln.RemoveByKey(key);

            toolReport.SelectedInterval = ItmToolStrip.DateInterval.CustomMonth;
        }

        private void SetNoneInterval()
        {
            //Для ежедневного отчёта выставим в ItmToolStrip "Всё время"

            var cln = toolReport.btnDateFilter.DropDown.Items;
            foreach (var key in cln.OfType<ToolStripItem>().Select(item => item.Name).ToList().Where(key => !key.Equals("tsmAllTime")))
                cln.RemoveByKey(key);

            toolReport.SelectedInterval = ItmToolStrip.DateInterval.AllTime;
        }

        private void Edit(SourceInformation info)
        {
            using (var dlg = new ReportDataDialog{
                 Source = info.Source,
                 PrivaryKeyName = info.PrimaryKeyName,
                 Captions = info.Captions,
                 // Добавил: Пантелеев М.Ю.
				 // Дата:    09.06.2015г.
				 // Передача 3-х дополнительных параметров отчёта.
				 UserName = this.UserName,
                 UpdateEqualValue = this.UpdateEqualValue,
                 NameFieldGroup = this.NameFieldGroup
            })
            {
                if (dlg.ShowDialog() == DialogResult.OK)
                {
                    var ids = Get2ColumnsTable(dlg.EditedData.Select( m => m.Id));
                    var caps = Get2ColumnsTable(dlg.EditedData.Select(m => m.DataFieldName));
                    var values = Get2ColumnsTable(dlg.EditedData
                        .Select(m => m.Value == null ?
                            //Обязательно надо заменить запятую на точку, для правильной записи в БД.
                            string.Empty : m.Value.ToString().Replace(",", ".")));

                    try
                    {
                        spc.FillTable("AlterReportTableParametrs",
                            "cTableNameIn", info.TableName, SqlDbType.NVarChar,
                            "tPrimaryKeyIn", ids, SqlDbType.Structured,
                            "tColumnNameIn", caps, SqlDbType.Structured,
                            "tValueIn", values, SqlDbType.Structured,
                            "cNoteIn", string.Empty, SqlDbType.NVarChar);
                    }
                    catch (Exception ex)
                    {
                        MessageBoxes.Error(this, ex, "Ошибка редактирования данных отчёта");
                    }

                    FillReport();
                }
            }
        }

        private DataTable Get2ColumnsTable<T>(IEnumerable<T> data)
        {
            var dt = new DataTable();
            dt.Columns.AddRange(new[] {
                new DataColumn("nId", typeof(int)),
                new DataColumn("nVal", typeof(T))
            });

            foreach (var val in data)
                dt.Rows.Add(
                    dt.Rows.Count + 1, string.IsNullOrEmpty(val.ToString()) 
                    ? (object)DBNull.Value : (object)val );

            return dt;
        }

        private void ShowMenu()
        {
            editMenu.Show(toolReport, new Point(tsbEdit.Bounds.Left, tsbEdit.Bounds.Bottom));
        }

        private void LoadUserData()
        {
            try
            {
                var dt = spc.FillTable("GetCurUsers");

                if (dt != null && dt.Rows.Count > 0)
                {
                    UserLogin = dt.Rows[0]["cLogin"].ToString();
                    UserName = dt.Rows[0]["cUserFullName"].ToString();
                }
            }
            catch (Exception ex)
            {
                MessageBoxes.Error(this, ex, "Ошибка загрузки данных пользователя.");
            }
        }

        #endregion Private Methods

        #region Private Members

        ContextMenuStrip editMenu;
        ToolStripButton tsbEdit;
        ToolStripComboBox tscbMaterials;

        #endregion Private Members
    }
}

