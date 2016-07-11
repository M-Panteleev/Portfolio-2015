##Дополнение к журналу сертификатов качества продукции.
<p align="justify">
<b>Описание:</b> было замечание, согласно которого в <a href="https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/Certificate/Screenshots/Certificate.png" target="_blank" title= "Открыть в новой вкладке">журнале</a> сертификатов качества отгружаемой продукции требовалось реализовать расчёт средневзвешенного хим. анализа как на основании автоматически рассчитанного хим. состава, так и на основании значений введённых вручную, при этом значения введённые вручную должны были иметь более высокий приоритет при расчёте.
</p>
![image1](https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/Certificate/Screenshots/Certificate.png "Журнал сертификатов качества")
<p align="center">Рисунок 1. Журнал сертификатов качества.</p>

<p align="justify">
В процессе работы было обнаружено, что некоторые сертификаты имели в химическом анализе некорректный порядок следования хим. компонентов, данная проблема также была обработана в текущем решении.<br> 
</p>

<h2></h2>
<i>Хранимая процедура, выполняющая пересчёт параметров сертификата: "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/Certificate/SQL/AlterCertificateBasicWeight.sql" target="_blank" title= "Открыть в новой вкладке">AlterCertificateBasicWeight.sql</a>";
<br> 
Хранимая процедура, выполняющая расчёт базового веса сертификата: "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/Certificate/SQL/GetCertificateBasicWeight.sql" target="_blank" title= "Открыть в новой вкладке">GetCertificateBasicWeight.sql</a>"; 
<br>
Хранимая процедура, выполняющая сортировку хим. состава сертификата в соответствии с порядком следования хим. компонентов: "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/Certificate/SQL/AlterCertificateSequenceValueProbe.sql" target="_blank" title= "Открыть в новой вкладке">AlterCertificateSequenceValueProbe.sql</a>".
