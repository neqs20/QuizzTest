extends Control

onready var Question : Label = $MainContainer/QuestionContainer/Question
onready var QuestionImage : TextureRect = $MainContainer/QuestionContainer/Image

onready var LongButtonsContainer : VBoxContainer = $MainContainer/AnswersContainer/Long
onready var ShortButtonsContainer : GridContainer = $MainContainer/AnswersContainer/Short

onready var Correct : Label = $MainContainer/StatsContainer/ValuesContainer/Correct
onready var Total : Label = $MainContainer/StatsContainer/ValuesContainer/Total
onready var Wrong : Label = $MainContainer/StatsContainer/ValuesContainer/Wrong

onready var Menu : Control = $HelpMenu
onready var SearchMenuButton : Button = $HelpMenu/ContentContainer/HelpButton

onready var SearchBar : LineEdit = $HelpMenu/ContentContainer/Content/SearchContainer/SearchBarContainer/SearchBar
onready var SearchButton : Button = $HelpMenu/ContentContainer/Content/SearchContainer/SearchBarContainer/SearchButton

onready var ResultButtonsContainer : VBoxContainer = $HelpMenu/ContentContainer/Content/SearchContainer/ResultsContainer
onready var ResultButtons : Array = ResultButtonsContainer.get_children()

onready var ArticleContainer : VBoxContainer = $HelpMenu/ContentContainer/Content/SearchContainer/ArticleContainer
onready var Content : RichTextLabel = $HelpMenu/ContentContainer/Content/SearchContainer/ArticleContainer/Content

onready var LongButtons : Array = LongButtonsContainer.get_children()
onready var ShortButtons : Array = ShortButtonsContainer.get_children()

const IMAGE_PLACEHOLDER : String = "<<\\d+.(png|jpg|gif)>>"
const FILE_PATH : String = "res://Global/Resources/Data/questions.txt"

const ARTICLES_NAMES_URL : String = "https://pl.wikipedia.org/w/api.php?action=opensearch&format=json&search="
const ARTICLE_URL : String = "https://pl.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=content&format=json&titles="

const DISABLED_STYLEBOX_PATH : String = "custom_styles/disabled"

const DISABLED_BUTTON_COLOR : Color = Color("676e78")
const CORRECT_BUTTON_PRESSED_COLOR : Color = Color("4abd84")
const WRONG_BUTTON_PRESSED_COLOR : Color = Color("d15d5b")

const data : Dictionary = {}
var regex : RegEx = RegEx.new()

var articles_name_fetcher : HTTPRequest = HTTPRequest.new()
var article_fetcher : HTTPRequest = HTTPRequest.new()

var data_indecies : Array = Array()
var indecies : Array = Array()

var current_question : String

var menu_visible : bool = false

func _ready() -> void:
	articles_name_fetcher.set_use_threads(true)
	articles_name_fetcher.connect("request_completed", self, "articles_name_downloaded")
	add_child(articles_name_fetcher)
	
	article_fetcher.set_use_threads(true)
	article_fetcher.connect("request_completed", self, "article_downloaded")
	add_child(article_fetcher)
	
	for i in range(ResultButtons.size()):
		ResultButtons[i].connect("pressed", self, "on_result_button_pressed", [i])
	
	regex.compile(IMAGE_PLACEHOLDER)
	
	var file : File = File.new()
	if not file.file_exists(FILE_PATH):
		print("File '%s' does not exist" % FILE_PATH)
		get_tree().quit()
		return
	if not file.open(FILE_PATH, File.READ) == OK:
		print("Cannot open (read) file '%s'" % FILE_PATH)
		get_tree().quit()
		return
	data_indecies = parse_file(file)
	randomize_indeces()
	prepare_question()

func button_pressed(index : int) -> void:
	for button in (LongButtons if LongButtonsContainer.is_visible_in_tree() else ShortButtons):
		button.pressed = false
		button.disabled = true
	Total.text = str(int(Total.text) + 1)
	var choosen_answer = data[current_question][index]
	if choosen_answer.right(choosen_answer.length() - 1) == "*":
		if LongButtonsContainer.is_visible_in_tree():
			LongButtons[index].get(DISABLED_STYLEBOX_PATH).bg_color = CORRECT_BUTTON_PRESSED_COLOR
		else:
			ShortButtons[index].get(DISABLED_STYLEBOX_PATH).bg_color = CORRECT_BUTTON_PRESSED_COLOR
		Correct.text = str(int(Correct.text) + 1)
	else:
		if LongButtonsContainer.is_visible_in_tree():
			LongButtons[index].get(DISABLED_STYLEBOX_PATH).bg_color = WRONG_BUTTON_PRESSED_COLOR
		else:
			ShortButtons[index].get(DISABLED_STYLEBOX_PATH).bg_color = WRONG_BUTTON_PRESSED_COLOR
		for i in range(4):
			if data[current_question][i][data[current_question][i].length() - 1] == "*":
				if LongButtonsContainer.is_visible_in_tree():
					LongButtons[i].get("custom_styles/disabled").bg_color = CORRECT_BUTTON_PRESSED_COLOR
				else:
					ShortButtons[i].get("custom_styles/disabled").bg_color = CORRECT_BUTTON_PRESSED_COLOR
				break
		Wrong.text = str(int(Wrong.text) + 1)

func reset_buttons() -> void:
	for button in (LongButtons if LongButtonsContainer.is_visible_in_tree() else ShortButtons):
		button.get(DISABLED_STYLEBOX_PATH).bg_color = DISABLED_BUTTON_COLOR
		button.disabled = false

func articles_name_downloaded(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
	if response_code == 200:
		ArticleContainer.set_visible(false)
		ResultButtonsContainer.set_visible(true)
		var json_data = parse_json(body.get_string_from_utf8())
		for i in range(int(max(json_data[1].size(), ResultButtons.size()))):
			if i < int(min(json_data[1].size(), ResultButtons.size())):
				ResultButtons[i].set_visible(true)
				ResultButtons[i].text = json_data[1][i]
			
func article_downloaded(result : int, response_code : int, headers : PoolStringArray, body : PoolByteArray) -> void:
	if response_code == 200:
		ArticleContainer.set_visible(true)
		ResultButtonsContainer.set_visible(false)
		var json_data = parse_json(body.get_string_from_utf8())
		Content.bbcode_text = parse_wikipedia_article(json_data.query.pages[json_data.query.pages.keys()[0]].revisions[0]['*'])
		

func parse_file(file : File) -> Array:
	while not file.eof_reached():
		var question = file.get_line()
		if question.empty():
			continue
		data[question] = []
		for i in range(4):
			data[question].push_back(file.get_line())
	return range(data.size())

func randomize_indeces() -> void:
	indecies = data_indecies.duplicate()
	randomize()
	indecies.shuffle()

func roll() -> String:
	var rand = indecies.pop_back()
	if rand == null:
		randomize_indeces()
		rand = indecies.pop_back()
	return data.keys()[rand]

func prepare_question() -> void:
	reset_buttons()
	current_question = roll()
	var found_match : RegExMatch = regex.search(current_question)
	var is_image_present : bool = not found_match == null
	if is_image_present:
		var image = File.new()
		var image_path = "res://Global/Assets/".plus_file(found_match.get_string().replace("<<", "").replace(">>", ""))
		if image.file_exists(image_path):
			QuestionImage.texture = load(image_path)
		else:
			QuestionImage.texture = load("res://Global/Assets/missing.png")
		Question.text = current_question.replace(found_match.get_string(), "")
	else:
		Question.text = current_question
	update_buttons(is_image_present)

func update_buttons(is_image_present : bool) -> void:
	QuestionImage.visible = is_image_present
	LongButtonsContainer.visible = not is_image_present
	ShortButtonsContainer.visible = is_image_present
	var i = 0
	for button in (ShortButtons if is_image_present else LongButtons):
		var answer = data[current_question][i]
		button.set_text(answer if not answer[answer.length() - 1] == "*" else answer.left(answer.length() - 1))
		i += 1

func on_roll_button_pressed() -> void:
	prepare_question()

func on_search_button_toggled(button_pressed):
	if button_pressed:
		Menu.rect_position.y = 0
	else:
		Menu.rect_position.y = 775

func on_menu_search_button_pressed():
	menu_visible = not menu_visible
	if menu_visible:
		Menu.rect_position.y = 0
		SearchBar.grab_focus()
		return
	Menu.rect_position.y = 775

func _on_MainMenu_gui_input(event):
	if event is InputEventMouseButton and event.pressed and menu_visible and (event.button_index == BUTTON_LEFT or event.button_index == BUTTON_RIGHT):
		SearchMenuButton.emit_signal("pressed")

func on_search_button_pressed():
	if articles_name_fetcher.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		articles_name_fetcher.request(ARTICLES_NAMES_URL + SearchBar.text.replace(" ", "_"))

func on_result_button_pressed(index : int) -> void:
	if article_fetcher.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		article_fetcher.request(ARTICLE_URL + ResultButtons[index].text.replace(" ", "_"))

func _on_SearchBar_text_entered(new_text):
	SearchButton.emit_signal("pressed")

func parse_wikipedia_article(data : String) -> String:
	return data
