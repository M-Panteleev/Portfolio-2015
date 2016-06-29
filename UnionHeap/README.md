##Функционал объединения хранилищ.
<p align="justify">
<b>Описание:</b> было такое замечание, согласно которого в <a href="https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/UnionHeap/Screenshots/ProductHeapLog.png" target="_blank" title= "Открыть в новой вкладке">журнале</a> хранилищ требовалось реализовать функциональную возможность объединения двух и более хранилищ в единое целое. В результате такого объединения должно было создаваться новое хранилище, имеющее средневзвешенный хим. состав вошедших в него исходных <a href="#user-content-note-1" title= "Перейти к сноске">терриконов</a>, которые, в свою очередь, должны были закрываться и отправляться в историю.
</p>
![image1](https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/UnionHeap/Screenshots/ProductHeapLog.png "Внешний вид журнала хранилищ")
<p align="center">Рисунок 1. Внешний вид журнала хранилищ.</p><br>

<p align="justify">
Пользователю должна была предоставляться возможность выбора исходных терриконов для объединения, а также возможность указания параметров результирующего террикона, таких как материал, фракция, место хранения, цех-владелец и т.д.
</p>
<br> 

![image1](https://raw.githubusercontent.com/M-Panteleev/Portfolio-2015/master/UnionHeap/Screenshots/ProductHeapUnionDialog.png "Внешний вид окна объединения терриконов")
<p align="center">Рисунок 2. Внешний вид окна объединения терриконов.</p>

<p align="justify">
Кроме того, требовалось реализовать операцию отмены объединения хранилищ, позволяющую восстановить первоначальные параметры исходных терриконов и их движений (изъятий, пополнений) до операции объединения.</p>

<br>
<i>Журнал хранилищ см.: "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/UnionHeap/CS/ProductHeapLog.cs" target="_blank" title= "Открыть в новой вкладке">ProductHeapLog.cs</a>";<br>
Диалоговое окно объединения см.: "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/UnionHeap/CS/ProductHeapUnionDialog.cs" target="_blank" title= "Открыть в новой вкладке">ProductHeapUnionDialog.cs</a>";<br>
Хранимая процедура выполняющая объединение хранилищ см.: "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/UnionHeap/SQL/UnionHeap.sql" target="_blank" title= "Открыть в новой вкладке">UnionHeap.sql</a>";<br>
Хранимая процедура, выполняющая расчёт веса и средневзвешенного хим. анализа результирующего террикона см.: "<a href="https://github.com/M-Panteleev/Portfolio-2015/blob/master/UnionHeap/SQL/GetWeightAndChemAnalysisHeapUnion.sql" target="_blank" title= "Открыть в новой вкладке">GetWeightAndChemAnalysisHeapUnion.sql</a>".</i><br><br>

<h2></h2>
<a id = note-1> </a>
<p align="justify"><b><i>Террикон</b> (хранилище) - представляет собой единицу складирования готовой продукции. По форме террикон представляет собой насыпь конусообразного вида. Каждый террикон имеет определённую фракцию и химический состав. Формирование террикона происходит в результате внутрицеховых (из бункера дробильной установки) или межцеховых перевозок. В качестве мест хранения терриконов выступают площадки цеха, либо внешние склады.</i>
<a href="#start-of-content" title= "В начало страницы">[<b>↩</b>]</a>
</p>
