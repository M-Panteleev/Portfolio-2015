##Простои технологического оборудования.
<p align="justify"><b>Описание:</b> хранимая процедура "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/EquipmentDowntime/SQL/GetEquipmentDowntime.sql" target="_blank" title= "Открыть в новой вкладке">GetEquipmentDowntime</a>" осуществляет сбор данных о простоях технологического оборудования плавильных цехов на linked-серверах.</p>

<p align="justify">Каждый цех имеет свой сервер и свои БД, процедура идентична для всех цехов. Запуск хранимой процедуры инициируется по расписанию SQL Агентом Главного сервера. Главный сервер через вызовы промежуточных процедур-обёрток, осуществляет вызов хранимой процедуры "GetEquipmentDowntime" на каждом linked-сервере плавильного цеха. Вызов осуществлялся последовательно по линку через exec-вызовы с передачей параметров и сохранением полученного рекордсета в таблицу простоев Главного сервера. Исходные данные по пуску/останову оборудования в локальных БД linked-серверов наполняются путём импорта данных из технологической базы АСУ ТП.<br>
<br>
Получаемые с linked-серверов данные сохраняются в расширенную таблицу на Главном сервере, затем полученная информация о простоях оборудования  экспортируется в SAP.</p>