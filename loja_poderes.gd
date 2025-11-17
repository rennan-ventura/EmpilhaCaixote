extends Control

# Assumindo que SupabaseClient é um Singleton (Autoload)
const Supabase = preload("res://addons/supabase/Supabase/supabase.gd") # AJUSTE O CAMINHO
var supabase_client: Node = null

# Variáveis de estado local
var total_moedas: int = 0
var total_diamantes: int = 0 # Mantido, mas não usado para compra
var user_id: String = ""
# Dicionário onde a chave é o ID do poder e o valor é a quantidade possuída {1: 5, 2: 0, ...}
var poderes_possuidos: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0} 

# Referências para as Labels de saldo
@onready var label_moedas: Label = $LabelMoedas 
@onready var label_diamantes: Label = $LabelDiamantes 


# --- Estrutura dos Poderes ---
const CUSTO_POWER: int = 1500
const PODERES_DISPONIVEIS = {
	"poder1": {"power_id": 1, "cost_coins": CUSTO_POWER},
	"poder2": {"power_id": 2, "cost_coins": CUSTO_POWER},
	"poder3": {"power_id": 3, "cost_coins": CUSTO_POWER},
	"poder4": {"power_id": 4, "cost_coins": CUSTO_POWER},
}


# ==========================================================
# --- FUNÇÕES DE ATUALIZAÇÃO DA UI E CONEXÃO ---
# ==========================================================

func _atualizar_display_moedas():
	label_moedas.text = str(total_moedas)

func _atualizar_display_diamantes():
	label_diamantes.text = str(total_diamantes) 


func _ready() -> void:
	# 1. Obter a referência do Singleton e conectar os sinais
	supabase_client = get_node("/root/SupabaseClient")
	
	if is_instance_valid(supabase_client):
		# Conexão para carregar dados gerais (coins, gems)
		supabase_client.data_carregada.connect(_on_dados_iniciais_carregados) 
		# Conexão para carregar a lista de poderes possuídos
		supabase_client.poderes_carregados.connect(_on_poderes_possuidos_carregados) 
		# Conexão para salvar a transação
		supabase_client.transacao_poder_salva.connect(_on_transacao_poder_salva) 
		
		user_id = supabase_client.current_user_id
		
		if user_id.is_empty():
			printerr("ERRO: ID do usuário vazio.")
		else:
			# 2. Inicia o carregamento de todos os dados
			supabase_client.carregar_dados_usuario(user_id) # Carrega coins e gems
			supabase_client.carregar_poderes_usuario(user_id) # Carrega lista de poderes
	else:
		printerr("ERRO: O Singleton SupabaseClient não está carregado.")

# ==========================================================
# --- LOGICA DE COMPRA E VERIFICAÇÃO ---
# ==========================================================

func comprar_poder(poder_key: String):
	var poder = PODERES_DISPONIVEIS[poder_key]
	var custo_moedas = poder.cost_coins
	var power_id = poder.power_id
	
	if total_moedas < custo_moedas:
		print("COMPRA FALHOU: Saldo insuficiente de moedas (Requer:", custo_moedas, ").")
		return

	# Se a compra for válida:
	# 1. Calcula o novo total de moedas
	var novo_total_moedas = total_moedas - custo_moedas
	
	# 2. Atualiza a UI de moedas imediatamente para feedback rápido
	total_moedas = novo_total_moedas
	_atualizar_display_moedas()

	# 3. Calcula a nova quantidade (incrementa 1)
	var nova_quantidade = poderes_possuidos.get(power_id, 0) + 1
	
	# 4. Envia a transação de atualização para o DB
	print("Enviando transação de compra de poder para o DB...")
	
	# O Singleton deve salvar o novo saldo de moedas E atualizar/inserir o poder.
	supabase_client.salvar_compra_poder(user_id, novo_total_moedas, power_id, nova_quantidade)

# ==========================================================
# --- HANDLERS DE SINAIS (RESPOSTAS DO SINGLETON) ---
# ==========================================================

# Handler de Carregamento de Dados Gerais (Coins/Gems)
func _on_dados_iniciais_carregados(data: Dictionary):
	total_moedas = data.coins
	total_diamantes = data.gems
	_atualizar_display_moedas()
	_atualizar_display_diamantes()

# Handler de Carregamento de Poderes Possuídos
func _on_poderes_possuidos_carregados(power_qtys: Dictionary):
	poderes_possuidos = power_qtys
	print("Poderes possuídos carregados:", poderes_possuidos)
	# Não atualiza nenhuma Label de quantidade.

# Handler de Salvamento da Transação
func _on_transacao_poder_salva(success: bool, new_coins: int, power_id: int, new_qty: int):
	if success:
		# 1. Atualiza o estado local com o novo saldo de moedas
		total_moedas = new_coins
		# 2. Atualiza a quantidade do poder (mesmo que não exiba)
		poderes_possuidos[power_id] = new_qty
		
		_atualizar_display_moedas()
		print("Poder ID ", power_id, " comprado e salvo no DB. Nova Qty:", new_qty)
	else:
		# Se falhar, recarrega o saldo para reverter a mudança local
		print("Falha ao salvar a compra de poder. Recarregando dados...")
		supabase_client.carregar_dados_usuario(user_id) 


# --- Sinais dos Botões (Conectados) ---

func _on_poder_1_btn_pressed() -> void:
	comprar_poder("poder1")

func _on_poder_2_btn_pressed() -> void:
	comprar_poder("poder2")

func _on_poder_3_btn_pressed() -> void:
	comprar_poder("poder3")

func _on_poder_4_btn_pressed() -> void:
	comprar_poder("poder4")

# --- Outras Funções do Script Original (Mantidas) ---

func _on_aba_cenarios_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_cenarios.tscn")


func _on_aba_moedas_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_moedas.tscn")


func _on_aba_diamantes_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_diamantes.tscn")


func _on_sair_btn_pressed() -> void:
	get_tree().quit()


func _on_voltar_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
