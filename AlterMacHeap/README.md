﻿##Механизм автоматического перерасчёта параметров хранилищ.

Механизм автоматического перерасчёта параметров [хранилищ](#user-content-note-1 "Перейти к сноске") осуществляет:
- расчёт масс;<br>
- расчёт средневзвешенного химического анализа;<br>
- сортировку хим. анализа в соответствии с порядком следования хим. компонентов;
- обновление данных;<br>
- ведение истории изменений.
<br>

<p align="justify">
<b>Описание:</b> функционал выполняет проверку актуальности параметров хранилищ завода, в случае обнаружения несоответствий выполняется их автоматический перерасчёт. Проверяемыми параметрами являются масса и средневзвешенный химический состав, в качестве проверочных выступают эти же параметры, но полученные методом расчёта (согласно стека операций хранилищ). В случае, если значения массы и хим. состава хранилища в таблице "macHeap" отличаются от рассчитанных - осуществляется их замена последними (данные полученные в результате расчёта являются приоритетными в плане достоверности).
</p>

![image1](https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/AlterMacHeap/Screenshots/AlterMacHeap.png "Структурная схема вызовов")
<p align="center">Рисунок 1. Структурная схема вызовов (см.<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/AlterMacHeap/Screencasts/AlterMacHeap.mp4?raw=true" target="_blank" title= "Скачать">видео</a>).</p>
<b>Операциями хранилища являются:</b>
<br>
- входящие автомобильные перевозки (пополнения);<br>
- исходящие автомобильные перевозки (изъятия);<br>
- замеры;<br>
- зачистки;<br> 
- объединения хранилищ;<br>
- откаты операций и т.д.<br>
(<i>стек операций хранилища может содержать от десятков до тысяч операций</i>).<br>

<p align="justify">
Поверка и перерасчёт параметров хранилищ являлись ключевыми задачами функционала, но в процессе разработки были выявлены дополнительные замечания, обработка которых была включена в общий функционал. К таким дополнениям относится: сортировка хим. анализа хранилищ и выполненных по ним операций, в соответствии с порядком следования хим. компонентов (для разных видов продукции набор хим. элементов в составе и порядок их следования различен).
</p>

- Обновление параметров хранилищ реализовано в хранимой процедуре "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/AlterMacHeap/SQL/macHeap/AlterMacHeap.sql" target="_blank" title= "Открыть в новой вкдадке">AlterMacHeap</a>".
- Расчёт проверочных значений (согласно операций хранилищ) в ХП "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/AlterMacHeap/SQL/CommonObjects/GetHeapWeight.sql" target="_blank" title= "Открыть в новой вкдадке">GetHeapWeight</a>".
- Сортировка хим. анализа в соответствии с порядком следования хим. компонентов в ХП "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/AlterMacHeap/SQL/CommonObjects/AlterSequenceValueProbeHeapOperation.sql" target="_blank" title= "Открыть в новой вкдадке">AlterSequenceValueProbeHeapOperation</a>".
<br>
<br>

<i>Cтруктурную схему см. на <a href="https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/AlterMacHeap/Screenshots/AlterMacHeap.png" target="_blank" title= "Открыть в новой вкдадке">рисунке</a>.<br>
Описание принципа действия см. в <a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/AlterMacHeap/Screencasts/AlterMacHeap.mp4?raw=true" target="_blank" title= "Скачать">видео</a>.<br>
Журнал просмотра истории изменений см. <a href="https://github.com/M-Panteleev/Portfolio-2015/tree/master/AlterHeapLog" target="_blank" title= "Открыть в новой вкдадке">здесь</a>.</i><br>
<br>

<h2></h2>
<a id = note-1> </a>
<p align="justify"><b>1. <i>Хранилище</b> (террикон) - представляет собой единицу складирования готовой продукции. По форме террикон представляет собой насыпь конусообразного вида. Каждый террикон имеет определённую фракцию и химический состав. Формирование террикона происходит в результате внутрицеховых (из бункера дробильной установки) или межцеховых перевозок. В качестве мест хранения терриконов выступают площадки цеха, либо внешние склады.</i>
<a href="#start-of-content" title= "В начало страницы">[<b>↩</b>]</a><br>

<a id = note-2> </a>
<p align="justify"><b>2. <i>Сервис-планировщик</b> разработан для циклического выполнения пользовательских заданий, написанных на языке скриптов стандарта <a href="http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-262.pdf" target="_blank" title= "Открыть в новом окне">ECMA-262</a>. Сам сервис написан на языке программирования C++ под Qt Framework 4.7.<br>
Выполнение заданий сервисом осуществляется согласно расписания, указываемого пользователем в файле «crontab» соответствующего <a href="https://ru.wikipedia.org/wiki/Cron" target="_blank" title= "Открыть в новом окне">формата</a>. Файл «crontab» содержит список скриптов и расписания их запуска. Формат файла заимствован из *NIX систем и немного видоизменен.<br>
Для отладки заданий сервис снабжён специальным отладчиком скриптов.<br>
Настройка, управление и удаленный мониторинг состояния сервиса реализованы через Веб-интерфейс. Структурно Веб-интерфейс разделен на четыре компонента: "Опции", "Список заданий", "Стек ошибок" и "Лог". Доступ к возможностям Веб-интерфейса осуществляется после аутентификации пользователя.</i>
<a href="#start-of-content" title= "В начало страницы ">[<b>↩</b>]</a><br>
</p>
