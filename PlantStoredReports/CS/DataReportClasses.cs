// Пантелеев М.Ю.: Текст отформатирован для просмотра на GitHub!

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data;
using System.Windows.Forms;

namespace Itm.WClient.FactoryServices.StoredReports
{
    
    /// <summary>
    /// Класс данных для поля грида редактирования.
    /// </summary>
    /// <remarks>
    /// Автор: Родшелев С.А.
    /// Ред.:               Пантелеев М.Ю.
    /// Дата:               09.06.2015г.
    /// </remarks>
    public class EditableFieldInformation
    {
        /// <summary>
        /// Наименование заголовка столбца
        /// </summary>
        public string HeaderText {get; set;}

        /// <summary>
        /// Наименование поля данных
        /// </summary>
        public string DataFieldName { get; set; }

        /// <summary>
        /// Флаг возможности редактирования поля.
        /// </summary>
        public bool ReadOnly { get; set; }

        /// <summary>
        /// Режим автоматической установки ширина поля (по содержимому, по ширине грида и т.д.).
        /// </summary>
        public DataGridViewAutoSizeColumnMode SizeMode { get; set; }

        // Добавил: Пантелеев М.Ю.
        // Дата:    09.06.2015г.
        // Добавлены 3-и свойства поля: "Width", "MinimumWidth", "TypeContent".
         
        /// <summary>
        /// Ширина поля(используется в ситуации, когда необходимо изменить значение по умолчанию).
        /// </summary>
        public int? Width { get; set; }
        
        /// <summary>
        /// Минимальная ширина поля(используется в ситуации, когда необходимо изменить значение по умолчанию).
        /// </summary>
        public int? MinimumWidth { get; set; }

        /// <summary>
        /// Свойство столбца.
        /// Если "DateEdit", значит при редактировании содержимого грида в текущее поле 
        /// будет записана дата изменения(автоматически).
        /// Если "UserName", значит при редактировании содержимого грида в текущее поле
        /// будет записано ФИО пользователя внёсшего изменения(автоматически).
        /// </summary>
        public TypeContent TypeContent { get; set; }
       
    }
    // Добавил: Пантелеев М.Ю.
    // Дата:    09.06.2015г.
    /// <summary>
    /// Свойство столбца.
    /// Если "DateEdit", значит при редактировании содержимого грида в текущее поле 
    /// будет записана дата изменения.
    /// Если "UserName", значит при редактировании содержимого грида в текущее поле
    /// будет записано ФИО пользователя внёсшего изменения.
    /// </summary>
    public enum TypeContent
    {
        /// <summary>
        /// Поле с данным статусом содержит дату последнего изменения записи. 
        /// Изменение записи в гриде (в окне редактирования данных отчёта) 
        /// приведёт к обновлению данного поля в таблице SQL сервера на текущую дату 
        /// в местном часовом поясе пользователя.
        /// </summary>
        DateEdit = 1,

        /// <summary>
        /// Поле с данным статусом содержит ФИО пользователя  отредактировавшего данные. 
        /// Изменение записи в гриде (в окне редактирования данных отчёта) 
        /// приведёт к обновлению данного поля в таблице SQL сервера на ФИО текущего пользователя. 
        /// </summary>
        UserName = 2,
    }
	
    // Добавил: Пантелеев М.Ю.
    // Дата:    09.06.2015г.
    /// <summary>
    /// Класс данных автоматического редактирования.
    /// </summary>
    public class AutoEditedFields
    {
        /// <summary>
        /// Наименование поля
        /// </summary>
        public string DataFieldName { get; set; }
        
        /// <summary>
        /// Свойство столбца.
        /// Если "DateEdit", значит при редактировании содержимого грида в текущее поле 
        /// будет записана дата изменения.
        /// Если "UserName", значит при редактировании содержимого грида в текущее поле
        /// будет записано ФИО пользователя внёсшего изменения.
        /// </summary>
        public TypeContent TypeContent { get; set; }
    }


    /// <summary>
    /// Класс данных редактирования.
    /// </summary>
    public class EditedInformation
    {
        /// <summary>
        /// ID записи.
        /// </summary>
        public int Id { get; set; }

        /// <summary>
        /// Наименование записи
        /// </summary>
        public string DataFieldName { get; set; }

        /// <summary>
        /// Значение.
        /// </summary>
        public object Value { get; set; }
    }

    /// <summary>
    /// Информация об источнике данных для редактирования данных отчёта.
    /// </summary>
    public class SourceInformation
    {
        /// <summary>
        /// Наименование источника, для отображения пользователю
        /// </summary>
        public string Caption { get; set; }

        /// <summary>
        /// Таблица с данными для отчёта.
        /// </summary>
        public DataTable Source { get; set; }

        /// <summary>
        /// Наименование таблицы в dbo.dcAnodeReportTable (поле cTableName)
        /// </summary>
        public string TableName { get; set; }

        /// <summary>
        /// Уникальное название поля ID для заданной таблицы
        /// </summary>
        public string PrimaryKeyName { get; set; }

        /// <summary>
        /// Данные для построения грида редактирования
        /// </summary>
        public List<EditableFieldInformation> Captions { get; set; }
    }

   
}

