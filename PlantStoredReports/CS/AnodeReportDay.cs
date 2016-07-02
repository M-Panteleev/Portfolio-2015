// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

using System;
using System.Collections.Generic;
using System.Linq;
using System.Data;
using System.ComponentModel;
using System.Windows.Forms;
using Microsoft.Reporting.WinForms;
using Itm.WClient.Com;

namespace Itm.WClient.FactoryServices.StoredReports
{
    /// <summary>
    /// Учёт электродной массы за сутки.
    /// </summary>
    /// <remarks>
    /// Автор: Родшелев С.А.
    /// Ред.:               Пантелеев М.Ю.
    /// Дата:               10.06.2015г.
    /// </remarks>
    [RequiredFile("rptAnodeReportDay.rdl")]
    [Description("Учёт электродной массы за сутки")]
    public class AnodeReportDay : PlantStoredReports
    {
        #region Constructor


        public AnodeReportDay()
        {
            //Интервал - ежедневный отчёт
            Interval = ReportIntervals.Day;

            ReportName = "Учёт электродной массы за сутки";

            // Добавил: Пантелеев М.Ю.
            // Дата: 10.06.2015г.
            // Флаг автоматического обновления идентичных значений.  
	    // "UpdateEqualValue = true" - обновлять идентичные значения для строк 
	    // состоящих в одной группе с изменяемой строкой 
	    // (группа строк определяется по одинаковому значению в поле "NameFieldGroup" - см. ниже).
            UpdateEqualValue = true;

            // Добавил: Пантелеев М.Ю.
            // Дата: 10.06.2015г.
            // Название числового поля, по которому будет определяется группа. 
            // Записи, имеющие одинаковое значение в данном поле, будут считаться состоящими в группе.
            NameFieldGroup = "nMaterialId";

            //Данные для редактирования
            EditedInfoList = new[] {
                new SourceInformation
                    {
                    TableName = "dcAnodeReportTable",
                    PrimaryKeyName = "nAnodeReportId",
                    
		    // Формирование списка полей грида.
		    // Список полей соответствует набору полей передаваемых хранимой процедурой текущего отчёта.
		    // Ред: Пантелеев М.Ю.
		    // Дата: 10.06.2015г.
		    // Добавлены 3-и дополнительных поля: "nRemainsWeightManualModif","dDateManualModif","cUserNameManualModif".
		    // Добавлены 2-а дополнительных свойства полей: "Width" и "TypeContent" (см. класс "DataReportClasses")
		    Captions = new List<EditableFieldInformation>
                    {
                        new EditableFieldInformation {
                            DataFieldName = "cNameMaterial",
                            HeaderText = "Поставщик ЭМ",
                            ReadOnly = true,
                            SizeMode = DataGridViewAutoSizeColumnMode.DisplayedCellsExceptHeader,
                        },
                        new EditableFieldInformation {
                            DataFieldName = "nIncomeWeight",
                            HeaderText = "Поступление, тн",
                            ReadOnly = true,
                            Width = 100
                        },
                        new EditableFieldInformation {
                            DataFieldName = "cNameUnit",
                            HeaderText = "Цех",
                            ReadOnly = true,
                            Width = 70
                        },
                        new EditableFieldInformation {
                            DataFieldName = "nConsumed",
                            HeaderText = "Расход, т",
                            ReadOnly = true
                        },
                        new EditableFieldInformation {
                            DataFieldName = "nRemains",
                            HeaderText = "Остаток (ориг.), т",
                            ReadOnly = true,
                            Width = 105
                        },
                        // Добавил: Пантелеев М.Ю.
			// Дата: 10.06.2015г.
			// Добавлены 3-и дополнительных поля: "nRemainsWeightManualModif","dDateManualModif","cUserNameManualModif".
				 
			// Остаток, т (поле доступное для ред. пользователем).
			new EditableFieldInformation {
                            DataFieldName = "nRemainsWeightManualModif",
                            HeaderText = "Остаток, т",
                            ReadOnly = false,
                        },
                        // Дата и время изменения данных пользователем в поле "nRemainsWeightManualModif".
			new EditableFieldInformation {
                            DataFieldName = "dDateManualModif",
                            HeaderText = "Дата изменения",
                            ReadOnly = true,
                            Width = 100,  
                            TypeContent = TypeContent.DateEdit
                        },
			// ФИО пользователя внёсшего изменения.
                        new EditableFieldInformation {
                            DataFieldName = "cUserNameManualModif",
                            HeaderText = "Пользователь",
                            ReadOnly = true,
                            TypeContent = TypeContent.UserName
                        }
               
                    }
                }
            };

            // добавление процедур по трем составляющим:
            // 1) ключ процедуры (синионим), 2) название процедуры в Sql-сервере без схемы, 
            // 3) назначение процедуры (v-чтение, e-редактирование)
            spc.AddProc(
                "rptAnodeReportDay", "rptAnodeReportDay", "v"
            );
        }

        #endregion Constructor

        #region Protected Members

        protected override void FillReportData(ReportDataSourceCollection sources, List<ReportParameter> pars)
        {
            // Получение даты начала выборки ХП в UTC.
	    DateTime? startDate = UserTimeZoneHelper.ToUniversalTime(BeginInterval, UserTimeZone);
			
	    // Формирование списка параметров RDL.
            pars.Add(new ReportParameter("dDateBegin",
                String.Format("{0:dd MMMM yyyy} г.", BeginInterval)));

            pars.Add(new ReportParameter("cLogin", UserLogin));
            pars.Add(new ReportParameter("cUserName", UserName));
			
	    // Вызов ХП с сохранением полученного рекордсета в переменную "dt".	
            var dt = spc.FillTable("rptAnodeReportDay",
                "dDateIn", startDate, SqlDbType.DateTime); 


            var rds = new ReportDataSource {Name = "DataSet", Value = dt};
            sources.Add(rds);

            // Отчёт редактируется, для его редактирования заполним данные.
            EditedInfoList.First().Source = dt;
        }

        #endregion Protected Members
    }
}

