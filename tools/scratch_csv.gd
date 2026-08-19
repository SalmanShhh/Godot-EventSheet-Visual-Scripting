extends SceneTree

const DIR := "res://addons/eventsheet/translations/"
const LANGS: PackedStringArray = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]

const ROWS: Array = [
["Set mass to {value}","Masse auf {value} setzen","Fijar masa a {value}","Définir la masse à {value}","Imposta massa a {value}","質量を {value} に設定","질량을 {value}(으)로 설정","Установить массу в {value}","将质量设为 {value}"],
["Set linear damping to {value}","Lineare Dämpfung auf {value} setzen","Fijar amortiguación lineal a {value}","Définir l'amortissement linéaire à {value}","Imposta smorzamento lineare a {value}","直線減衰を {value} に設定","선형 감쇠를 {value}(으)로 설정","Установить линейное затухание в {value}","将线性阻尼设为 {value}"],
["Set angular damping to {value}","Winkeldämpfung auf {value} setzen","Fijar amortiguación angular a {value}","Définir l'amortissement angulaire à {value}","Imposta smorzamento angolare a {value}","回転減衰を {value} に設定","각 감쇠를 {value}(으)로 설정","Установить угловое затухание в {value}","将角阻尼设为 {value}"],
["Set gravity scale to {value}","Schwerkraftfaktor auf {value} setzen","Fijar escala de gravedad a {value}","Définir l'échelle de gravité à {value}","Imposta scala di gravità a {value}","重力スケールを {value} に設定","중력 배율을 {value}(으)로 설정","Установить масштаб гравитации в {value}","将重力比例设为 {value}"],
["Set immovable","Unbeweglich machen","Hacer inamovible","Rendre immobile","Rendi immobile","動かせなくする","고정하기","Сделать неподвижным","设为不可移动"],
["Set movable","Beweglich machen","Hacer movible","Rendre mobile","Rendi mobile","動かせるようにする","움직이게 하기","Сделать подвижным","设为可移动"],
["Use physics material {value}","Physikmaterial {value} verwenden","Usar material físico {value}","Utiliser le matériau physique {value}","Usa materiale fisico {value}","物理マテリアル {value} を使う","물리 재질 {value} 사용","Использовать физматериал {value}","使用物理材质 {value}"],
["Set friction to {value}","Reibung auf {value} setzen","Fijar fricción a {value}","Définir le frottement à {value}","Imposta attrito a {value}","摩擦を {value} に設定","마찰을 {value}(으)로 설정","Установить трение в {value}","将摩擦设为 {value}"],
["Set elasticity to {value}","Elastizität auf {value} setzen","Fijar elasticidad a {value}","Définir l'élasticité à {value}","Imposta elasticità a {value}","弾性を {value} に設定","탄성을 {value}(으)로 설정","Установить упругость в {value}","将弹性设为 {value}"],
["Set world gravity to {value}","Weltschwerkraft auf {value} setzen","Fijar gravedad del mundo a {value}","Définir la gravité du monde à {value}","Imposta gravità del mondo a {value}","ワールド重力を {value} に設定","월드 중력을 {value}(으)로 설정","Установить гравитацию мира в {value}","将世界重力设为 {value}"],
["Apply torque {value}","Drehmoment {value} anwenden","Aplicar par {value}","Appliquer le couple {value}","Applica coppia {value}","トルク {value} を加える","토크 {value} 적용","Приложить момент {value}","施加扭矩 {value}"],
["Apply torque impulse {value}","Drehimpuls {value} anwenden","Aplicar impulso de par {value}","Appliquer l'impulsion de couple {value}","Applica impulso di coppia {value}","トルク力積 {value} を加える","토크 임펄스 {value} 적용","Приложить импульс момента {value}","施加扭矩冲量 {value}"],
["Apply impulse {value} at {offset}","Impuls {value} bei {offset} anwenden","Aplicar impulso {value} en {offset}","Appliquer l'impulsion {value} à {offset}","Applica impulso {value} a {offset}","力積 {value} を {offset} に加える","임펄스 {value}을(를) {offset}에 적용","Приложить импульс {value} в {offset}","在 {offset} 处施加冲量 {value}"],
["Apply force {value} at {offset}","Kraft {value} bei {offset} anwenden","Aplicar fuerza {value} en {offset}","Appliquer la force {value} à {offset}","Applica forza {value} a {offset}","力 {value} を {offset} に加える","힘 {value}을(를) {offset}에 적용","Приложить силу {value} в {offset}","在 {offset} 处施加力 {value}"],
["Create {kind} joint","{kind}-Gelenk erstellen","Crear articulación {kind}","Créer une articulation {kind}","Crea giunto {kind}","{kind} ジョイントを作る","{kind} 조인트 만들기","Создать шарнир {kind}","创建 {kind} 关节"],
["Is sleeping","Schläft","Está dormido","Est endormi","Sta dormendo","スリープ中","잠자는 중","Спит","处于休眠"],
["Is awake","Ist wach","Está despierto","Est éveillé","È sveglio","起きている","깨어 있음","Не спит","处于活动"],
["Is immovable","Ist unbeweglich","Es inamovible","Est immobile","È immobile","動かせない","고정됨","Неподвижен","不可移动"],
["Is not immovable","Ist nicht unbeweglich","No es inamovible","N'est pas immobile","Non è immobile","動かせる","고정되지 않음","Не неподвижен","可移动"],
["Is checked","Ist angehakt","Está marcado","Est coché","È spuntato","チェックされている","체크됨","Отмечено","已勾选"],
["Is not checked","Ist nicht angehakt","No está marcado","N'est pas coché","Non è spuntato","チェックされていない","체크되지 않음","Не отмечено","未勾选"],
["Set checked","Anhaken","Marcar","Cocher","Spunta","チェックする","체크하기","Отметить","勾选"],
["Set unchecked","Haken entfernen","Desmarcar","Décocher","Togli spunta","チェックを外す","체크 해제","Снять отметку","取消勾选"],
["Set text to {value}","Text auf {value} setzen","Fijar texto a {value}","Définir le texte à {value}","Imposta testo a {value}","テキストを {value} に設定","텍스트를 {value}(으)로 설정","Установить текст в {value}","将文本设为 {value}"],
["Set placeholder to {value}","Platzhalter auf {value} setzen","Fijar marcador a {value}","Définir le texte indicatif à {value}","Imposta segnaposto a {value}","プレースホルダーを {value} に設定","안내 문구를 {value}(으)로 설정","Установить подсказку поля в {value}","将占位文本设为 {value}"],
["Set formatted text to {value}","Formatierten Text auf {value} setzen","Fijar texto con formato a {value}","Définir le texte mis en forme à {value}","Imposta testo formattato a {value}","書式付きテキストを {value} に設定","서식 있는 텍스트를 {value}(으)로 설정","Установить форматированный текст в {value}","将富文本设为 {value}"],
["Append formatted text {value}","Formatierten Text {value} anhängen","Añadir texto con formato {value}","Ajouter le texte mis en forme {value}","Aggiungi testo formattato {value}","書式付きテキスト {value} を追加","서식 있는 텍스트 {value} 추가","Добавить форматированный текст {value}","追加富文本 {value}"],
["Switch to tab {value}","Zu Reiter {value} wechseln","Cambiar a la pestaña {value}","Passer à l'onglet {value}","Passa alla scheda {value}","タブ {value} に切り替え","탭 {value}(으)로 전환","Перейти на вкладку {value}","切换到标签页 {value}"],
["Set tooltip to {value}","Tooltip auf {value} setzen","Fijar tooltip a {value}","Définir l'infobulle à {value}","Imposta tooltip a {value}","ツールチップを {value} に設定","툴팁을 {value}(으)로 설정","Установить всплывающую подсказку в {value}","将提示设为 {value}"],
["Add item {value}","Eintrag {value} hinzufügen","Añadir elemento {value}","Ajouter l'entrée {value}","Aggiungi voce {value}","項目 {value} を追加","항목 {value} 추가","Добавить элемент {value}","添加条目 {value}"],
["Remove item {value}","Eintrag {value} entfernen","Quitar elemento {value}","Retirer l'entrée {value}","Rimuovi voce {value}","項目 {value} を削除","항목 {value} 제거","Удалить элемент {value}","移除条目 {value}"],
["Select item {value}","Eintrag {value} auswählen","Seleccionar elemento {value}","Sélectionner l'entrée {value}","Seleziona voce {value}","項目 {value} を選ぶ","항목 {value} 선택","Выбрать элемент {value}","选中条目 {value}"],
["Clear","Leeren","Vaciar","Vider","Svuota","空にする","비우기","Очистить","清空"],
["Has reached the end","Hat das Ende erreicht","Ha llegado al final","A atteint la fin","Ha raggiunto la fine","終点に着いた","끝에 도달함","Достиг конца","已到达终点"],
["Go to start","Zum Anfang","Ir al inicio","Aller au début","Vai all'inizio","始点に戻る","시작으로 가기","В начало","回到起点"],
["Set looping {state}","Wiederholen {state}","Repetición {state}","Boucle {state}","Ripetizione {state}","ループ {state}","반복 {state}","Повтор {state}","循环 {state}"],
["Set rotate with path {state}","Mit Pfad drehen {state}","Girar con la ruta {state}","Tourner avec le chemin {state}","Ruota con il percorso {state}","パスに合わせて回転 {state}","경로 따라 회전 {state}","Поворот по пути {state}","随路径旋转 {state}"],
["Set distance along path to {value}","Strecke auf dem Pfad auf {value} setzen","Fijar avance en la ruta a {value}","Définir la distance sur le chemin à {value}","Imposta distanza sul percorso a {value}","パス上の距離を {value} に設定","경로 위 거리를 {value}(으)로 설정","Установить путь по маршруту в {value}","将路径上的距离设为 {value}"],
["Add path point {value}","Pfadpunkt {value} hinzufügen","Añadir punto de ruta {value}","Ajouter le point de chemin {value}","Aggiungi punto del percorso {value}","パス点 {value} を追加","경로 점 {value} 추가","Добавить точку пути {value}","添加路径点 {value}"],
["Set pattern {name} to {value}","Muster {name} auf {value} setzen","Fijar patrón {name} a {value}","Définir le motif {name} à {value}","Imposta schema {name} a {value}","パターン {name} を {value} に設定","패턴 {name}을(를) {value}(으)로 설정","Установить шаблон {name} в {value}","将模式 {name} 设为 {value}"],
["Wait {seconds} seconds","{seconds} Sekunden warten","Esperar {seconds} segundos","Attendre {seconds} secondes","Attendi {seconds} secondi","{seconds} 秒待つ","{seconds}초 기다리기","Подождать {seconds} с","等待 {seconds} 秒"],
["Follow a Path","Pfad folgen","Seguir una ruta","Suivre un chemin","Segui un percorso","パスをたどる","경로 따라가기","Движение по пути","沿路径移动"],
["Text input","Texteingabe","Campo de texto","Champ de texte","Campo di testo","テキスト入力","텍스트 입력","Поле ввода","文本输入"],
["List","Liste","Lista","Liste","Elenco","リスト","목록","Список","列表"],
["Check box","Kontrollkästchen","Casilla","Case à cocher","Casella","チェックボックス","체크 상자","Флажок","复选框"],
["File chooser","Dateiauswahl","Selector de archivos","Sélecteur de fichiers","Selettore file","ファイル選択","파일 선택기","Выбор файла","文件选择器"],
["Tabs","Reiter","Pestañas","Onglets","Schede","タブ","탭","Вкладки","标签页"],
["blocks the game","blockiert das Spiel","bloquea el juego","bloque le jeu","blocca il gioco","ゲームが止まる","게임이 멈춤","останавливает игру","会卡住游戏"],
["regular expression","regulärer Ausdruck","expresión regular","expression régulière","espressione regolare","正規表現","정규식","регулярное выражение","正则表达式"],
["now (microseconds)","jetzt (Mikrosekunden)","ahora (microsegundos)","maintenant (microsecondes)","adesso (microsecondi)","現在 (マイクロ秒)","지금 (마이크로초)","сейчас (микросекунды)","现在（微秒）"],
["a pattern","ein Muster","un patrón","un motif","uno schema","パターン","패턴","шаблон","一个模式"],
["the match","der Treffer","la coincidencia","la correspondance","la corrispondenza","一致した文字列","일치한 부분","совпадение","匹配结果"],
["first match of {pattern} in {text}","erster Treffer von {pattern} in {text}","primera coincidencia de {pattern} en {text}","première correspondance de {pattern} dans {text}","prima corrispondenza di {pattern} in {text}","{text} 内の {pattern} の最初の一致","{text}에서 {pattern}의 첫 일치","первое совпадение {pattern} в {text}","{text} 中 {pattern} 的首个匹配"],
["all matches of {pattern} in {text}","alle Treffer von {pattern} in {text}","todas las coincidencias de {pattern} en {text}","toutes les correspondances de {pattern} dans {text}","tutte le corrispondenze di {pattern} in {text}","{text} 内の {pattern} のすべての一致","{text}에서 {pattern}의 모든 일치","все совпадения {pattern} в {text}","{text} 中 {pattern} 的全部匹配"],
["replace matches of {pattern} in {text} with {value}","Treffer von {pattern} in {text} durch {value} ersetzen","reemplazar coincidencias de {pattern} en {text} por {value}","remplacer les correspondances de {pattern} dans {text} par {value}","sostituisci le corrispondenze di {pattern} in {text} con {value}","{text} 内の {pattern} の一致を {value} に置き換える","{text}에서 {pattern}의 일치를 {value}(으)로 바꾸기","заменить совпадения {pattern} в {text} на {value}","把 {text} 中 {pattern} 的匹配替换为 {value}"],
["with","mit","con","avec","con","値:","값:","со значениями","其中"],
["revolute","Dreh","de rotación","pivot","rotante","回転","회전","вращательный","旋转"],
["distance","Abstand","de distancia","de distance","a distanza","距離","거리","расстояния","距离"],
["prismatic","Schiebe","prismática","glissière","prismatico","直動","직선","поступательный","滑动"],
["Text input ▸ On text changed","Texteingabe ▸ Bei Textänderung","Campo de texto ▸ Al cambiar el texto","Champ de texte ▸ Quand le texte change","Campo di testo ▸ Al cambio del testo","テキスト入力 ▸ テキストが変わったとき","텍스트 입력 ▸ 텍스트가 바뀌면","Поле ввода ▸ При изменении текста","文本输入 ▸ 当文本改变"],
["Text input ▸ On submitted","Texteingabe ▸ Bei Bestätigung","Campo de texto ▸ Al enviar","Champ de texte ▸ À la validation","Campo di testo ▸ All'invio","テキスト入力 ▸ 確定したとき","텍스트 입력 ▸ 입력을 마치면","Поле ввода ▸ При подтверждении","文本输入 ▸ 当提交"],
["List ▸ On item selected","Liste ▸ Bei Auswahl eines Eintrags","Lista ▸ Al elegir un elemento","Liste ▸ Quand une entrée est choisie","Elenco ▸ Alla scelta di una voce","リスト ▸ 項目が選ばれたとき","목록 ▸ 항목을 고르면","Список ▸ При выборе элемента","列表 ▸ 当选中条目"],
["File chooser ▸ On file chosen","Dateiauswahl ▸ Bei Dateiwahl","Selector de archivos ▸ Al elegir un archivo","Sélecteur de fichiers ▸ Quand un fichier est choisi","Selettore file ▸ Alla scelta di un file","ファイル選択 ▸ ファイルが選ばれたとき","파일 선택기 ▸ 파일을 고르면","Выбор файла ▸ При выборе файла","文件选择器 ▸ 当选择文件"],
["Tabs ▸ On tab changed","Reiter ▸ Bei Reiterwechsel","Pestañas ▸ Al cambiar de pestaña","Onglets ▸ Au changement d'onglet","Schede ▸ Al cambio scheda","タブ ▸ タブが変わったとき","탭 ▸ 탭이 바뀌면","Вкладки ▸ При смене вкладки","标签页 ▸ 当切换标签页"]
]


func _init() -> void:
	_append("TEMPLATE.csv", -1)
	for index: int in LANGS.size():
		_append("%s.csv" % LANGS[index], index + 1)
	print("csv done")
	quit(0)


func _append(file_name: String, column: int) -> void:
	var path: String = DIR + file_name
	var present: Dictionary = {}
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	while not handle.eof_reached():
		var row: PackedStringArray = handle.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		present[row[0]] = true
	handle.close()
	var out: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	out.seek_end()
	var added: int = 0
	for entry: Array in ROWS:
		var key: String = str(entry[0])
		if present.has(key):
			continue
		present[key] = true
		out.store_csv_line(PackedStringArray([key, "" if column < 0 else str(entry[column])]))
		added += 1
	out.close()
	print("%s: +%d" % [file_name, added])
