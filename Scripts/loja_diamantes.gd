extends Control

# Assumindo que SupabaseClient é um Singleton (Autoload)
const Supabase = preload("res://addons/supabase/Supabase/supabase.gd") # Ajuste o caminho conforme o seu projeto
var supabase_client: Node = null

# Variável de estado local que guarda o valor atual de diamantes.
var total_diamantes: int = 0
# ID do usuário (Obtido do Singleton)
var user_id: String = "" 

# Label deve ser criada na cena e chamada 'LabelDiamantes'
@onready var label_diamantes: Label = $LabelDiamantes 


# Função utilitária para atualizar o texto da Label.
func _atualizar_display_diamantes():
	label_diamantes.text = str(total_diamantes)
	print("Display UI atualizado. Diamantes:", total_diamantes)


# ==========================================================
# --- FUNÇÕES DE CONEXÃO COM O SINGLETON E LÓGICA DA LOJA ---
# ==========================================================

func _ready() -> void:
	# 1. Obter a referência do Singleton e conectar os sinais
	supabase_client = get_node("/root/SupabaseClient") # Ajuste o nome do Autoload se for diferente
	if is_instance_valid(supabase_client):
		supabase_client.diamantes_carregados.connect(_on_diamantes_carregados_do_db)
		supabase_client.diamantes_salvos.connect(_on_diamantes_salvos_no_db)
		
		# 2. Obter o ID do usuário (assumindo que o Singleton o define)
		user_id = supabase_client.current_user_id
		
		if user_id.is_empty():
			printerr("ERRO: ID do usuário vazio. Não é possível carregar dados do DB.")
			_atualizar_display_diamantes() # Mostra 0
		else:
			# 3. Inicia o carregamento dos diamantes
			supabase_client.carregar_diamantes(user_id)
	else:
		printerr("ERRO: O Singleton SupabaseClient não está carregado.")


# --- Handlers dos Sinais do DB ---

# Chamado quando o DB retorna o valor inicial de diamantes
func _on_diamantes_carregados_do_db(gems: int):
	total_diamantes = gems
	_atualizar_display_diamantes()
	print("Diamantes iniciais carregados do DB:", total_diamantes)

# Chamado após o DB confirmar que o valor foi salvo
func _on_diamantes_salvos_no_db(success: bool, new_gems: int):
	if success:
		# Atualizamos o estado local apenas para o valor confirmado pelo DB
		total_diamantes = new_gems 
		_atualizar_display_diamantes()
		print("Compra bem-sucedida e salva no DB!")
	else:
		# Se a transação falhar, o estado local permanece o mesmo e a UI é atualizada
		_atualizar_display_diamantes()
		print("Falha ao salvar compra. Tente novamente.")

# Função genérica para processar a compra de diamantes
func comprar_pacote(quantidade: int):
	if user_id.is_empty():
		printerr("Não é possível comprar: usuário não identificado.")
		return
		
	# 1. Calcula o novo valor
	var novo_total = total_diamantes + quantidade
	
	# 2. Chama a função do Singleton para atualizar o banco
	# A UI só será atualizada (via _on_diamantes_salvos_no_db) APÓS a confirmação do DB.
	print("Enviando compra de +", quantidade, " para o DB...")
	supabase_client.salvar_diamantes(user_id, novo_total)


# --- Sinais dos Botões (Conectados) ---

func _on_diama_1_btn_pressed() -> void:
	comprar_pacote(10)

func _on_diama_2_btn_pressed() -> void:
	comprar_pacote(30)

func _on_diama_3_btn_pressed() -> void:
	comprar_pacote(100)

func _on_diama_4_btn_pressed() -> void:
	comprar_pacote(300)

# --- Outras Funções do Script Original (Mantidas) ---

func _process(delta: float) -> void:
	pass 

func _on_aba_poderes_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_poderes.tscn")

func _on_aba_cenarios_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_cenarios.tscn")

func _on_aba_moedas_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_moedas.tscn")

func _on_button_pressed() -> void:
	pass

func _on_comecar_btn_pressed() -> void:
	pass


func _on_sair_btn_pressed() -> void:
	get_tree().quit()


func _on_voltar_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
