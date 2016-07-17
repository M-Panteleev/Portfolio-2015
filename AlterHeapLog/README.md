##Журнал просмотра истории изменений терриконов. 

<b>Описание:</b> <a href="https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/AlterHeapLog/Screenshots/AlterHeapLog.png" target="_blank" title= "Открыть в новом окне">журнал</a> предназначен для просмотра истории изменений [терриконов](#user-content-note-1 "Перейти к сноске"). Изменение параметров терриконов осуществляются <a href="#note-1" title= "Перейти к сноске">сервисом</a> синхронизации в автоматическом режиме. Журнал в наглядной форме отображает историю произведенных сервисом изменений.<br>
<br>
![image1](https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/AlterHeapLog/Screenshots/AlterHeapLog.png "Журнал  истории изменений терриконов")
<p align="center">Рисунок 1. Журнал истории изменений терриконов.</p>
<b>Назначение журнала:</b>
<br>
- оперативный доступ к истории изменений терриконов (например, при разрешении конфликтных ситуаций в вопросах с хранилищами);
- мониторинг выполнения хранимых процедур выполняющих автоматическое изменение производственных данных (работа с хранилищами ведётся круглосуточно пользователями плавильных цехов, автомобильных и Ж/Д весовых, участков погрузки готовой продукции и других подразделений завода);<br>
- анализ проблемных хранилищ, выявление дополнительных условий и критериев, изучение ошибок в операциях пополнения и изъятия, анализ последствий слияния, зачистки и замеров терриконов и т.д.;
- полное либо частичное копирование интересующей информации в буфер обмена с возможностью последующей вставки в MS Excel или MS Word с сохранением исходной табуляции.
<br>

<b>Функциональные особенности журнала:</b>
<br>
- полная детализация всех параметров до и после изменения (массы, фракции, хим. состав, GUID'ы, ID и прочее);<br>
- быстрая навигация (сортировка, горячие фильтры, фильтры по содержимому, фильтры по дате);<br>
- цветовая индикация (выделение цветом ячеек до и после изменения, окрашивание в соответствии со статусами записей, возможность просмотра легенды цветов и т.д.);<br>
- отображение причин приведших к пересчёту параметров террикона;<br>
- возможность копирования данных в буфер обмена;<br>
- возможность копирования данных с заголовками столбцов и без;<br> 
- возможность применения горячих клавиш и т.д.<br>
<br>

<i>Механизм автоматического перерасчёта параметров хранилищ см. <a href="https://github.com/M-Panteleev/Portfolio-2015/tree/master/AlterMacHeap" target="_blank" title= "Открыть в новой вкдадке">здесь</a>.</i><br>
<br>

<h2></h2>
<a id = note-1> </a>
<p align="justify"><b>1. <i>Террикон</b> - представляет собой единицу складирования готовой продукции. По форме террикон представляет собой насыпь конусообразного вида. Каждый террикон имеет определённую фракцию и химический состав. Формирование террикона происходит в результате внутрицеховых (из бункера дробильной установки) или межцеховых перевозок. В качестве мест хранения терриконов выступают площадки цеха, либо внешние склады.</i>
<a href="#start-of-content" title= "В начало страницы">[<b>↩</b>]</a><br>

<a id = note-2> </a>
<p align="justify"><b>2. <i>Сервис-планировщик</b> разработан для циклического выполнения пользовательских заданий, написанных на языке скриптов стандарта <a href="http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-262.pdf" target="_blank" title= "Открыть в новом окне">ECMA-262</a>. Сам сервис написан на языке программирования C++ под Qt Framework 4.7.<br>
Выполнение заданий сервисом осуществляется согласно расписания, указываемого пользователем в файле «crontab» соответствующего <a href="https://ru.wikipedia.org/wiki/Cron" target="_blank" title= "Открыть в новом окне">формата</a>. Файл «crontab» содержит список скриптов и расписания их запуска. Формат файла заимствован из *NIX систем и немного видоизменен.<br>
Для отладки заданий сервис снабжён специальным отладчиком скриптов.<br>
Настройка, управление и удаленный мониторинг состояния сервиса реализованы через Веб-интерфейс. Структурно Веб-интерфейс разделен на четыре компонента: "Опции", "Список заданий", "Стек ошибок" и "Лог". Доступ к возможностям Веб-интерфейса осуществляется после аутентификации пользователя.</i>
<a href="#start-of-content" title= "В начало страницы ">[<b>↩</b>]</a><br>
</p>