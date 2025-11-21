extends Control

# Assumindo que SupabaseClient é um Singleton (Autoload)
const Supabase = preload("res://addons/supabase/Supabase/supabase.gd") # AJUSTE O CAMINHO
var supabase_client: Node = null

# Variáveis de estado local
var total_moedas: int = 0
var total_diamantes: int = 0
var user_id: String = ""
# Lista dos IDs das skins/cenários que o usuário possui.
var cenarios_possuidos: Array = [] 

# Referências para as Labels
@onready var label_moedas: Label = $LabelMoedas 
@onready var label_diamantes: Label = $LabelDiamantes 

# --- Estrutura dos Cenários (ID do item no banco e custo) ---
const CENARIOS_DISPONIVEIS = {
	"cenario1": {"skin_id": 1, "cost_gems": 50}, # Assumindo ID 1 para Cenario 1
	"cenario2": {"skin_id": 2, "cost_gems": 50}, # Assumindo ID 2 para Cenario 2
	"cenario3": {"skin_id": 3, "cost_gems": 50}, # Assumindo ID 3 para Cenario 3
	"cenario4": {"skin_id": 4, "cost_gems": 50}, # Assumindo ID 4 para Cenario 4
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
	supabase_client = get_node("/root/SupabaseClient") # Ajuste o nome do Autoload
	
	if is_instance_valid(supabase_client):
		# Conexão para carregar dados gerais (coins, gems)
		supabase_client.data_carregada.connect(_on_dados_iniciais_carregados) 
		# Conexão para carregar a lista de cenários/skins possuídas
		supabase_client.skins_carregadas.connect(_on_cenarios_possuidos_carregados) # NOVO SINAL!
		# Conexão para salvar a transação
		supabase_client.transacao_compra_salva.connect(_on_transacao_compra_salva) # NOVO SINAL!
		
		user_id = supabase_client.current_user_id
		
		if user_id.is_empty():
			printerr("ERRO: ID do usuário vazio. Não é possível carregar dados.")
			_atualizar_display_moedas()
			_atualizar_display_diamantes()
		else:
			# 2. Inicia o carregamento de todos os dados necessários
			supabase_client.carregar_dados_usuario(user_id) # Carrega coins e gems
			supabase_client.carregar_skins_usuario(user_id) # NOVO: Carrega lista de skins
	else:
		printerr("ERRO: O Singleton SupabaseClient não está carregado.")

# ==========================================================
# --- LOGICA DE COMPRA E VERIFICAÇÃO ---
# ==========================================================

func comprar_cenario(cenario_key: String):
	var cenario = CENARIOS_DISPONIVEIS[cenario_key]
	var custo_diamantes = cenario.cost_gems
	var skin_id = cenario.skin_id
	
	if cenarios_possuidos.has(skin_id):
		print("COMPRA FALHOU: Cenário ID ", skin_id, " já possuído.")
		# Opcional: Desabilitar o botão aqui
		return

	if total_diamantes < custo_diamantes:
		print("COMPRA FALHOU: Saldo insuficiente de diamantes (Requer:", custo_diamantes, ").")
		return

	# Se a compra for válida:
	# 1. Calcula o novo total de diamantes
	var novo_total_diamantes = total_diamantes - custo_diamantes
	
	# 2. Atualiza a UI imediatamente para feedback rápido (opcional)
	total_diamantes = novo_total_diamantes
	_atualizar_display_diamantes()

	# 3. Envia a transação de atualização para o DB
	print("Enviando transação de compra de cenário para o DB...")
	# NOTA: O Singleton deve agora salvar o novo saldo de diamantes E inserir a nova skin.
	supabase_client.salvar_compra_cenario(user_id, novo_total_diamantes, skin_id)

# ==========================================================
# --- HANDLERS DE SINAIS (RESPOSTAS DO SINGLETON) ---
# ==========================================================

# Handler de Carregamento de Dados Gerais (Coins/Gems)
func _on_dados_iniciais_carregados(data: Dictionary):
	total_moedas = data.coins
	total_diamantes = data.gems
	_atualizar_display_moedas()
	_atualizar_display_diamantes()

# Handler de Carregamento de Skins Possuídas (Novo)
func _on_cenarios_possuidos_carregados(skins_ids: Array):
	cenarios_possuidos = skins_ids
	print("Cenários possuídos carregados:", cenarios_possuidos)
	# Opcional: Atualizar botões para desabilitar itens já possuídos.

# Handler de Salvamento da Transação (Novo)
func _on_transacao_compra_salva(success: bool, new_gems: int, new_skin_id: int):
	if success:
		# 1. Atualiza o estado local com o novo saldo
		total_diamantes = new_gems
		# 2. Adiciona o cenário à lista de possuídos
		cenarios_possuidos.append(new_skin_id)
		
		_atualizar_display_diamantes()
		print("Cenário ID ", new_skin_id, " comprado e salvo no DB!")
		# Opcional: Atualizar botão para desabilitar
	else:
		# Se falhar, recarrega o saldo para reverter a mudança local
		print("Falha ao salvar a compra de cenário. Recarregando dados...")
		supabase_client.carregar_dados_usuario(user_id) 


# --- Sinais dos Botões (Conectados) ---

func _on_cenario_1_btn_pressed() -> void:
	comprar_cenario("cenario1")

func _on_cenario_2_btn_pressed() -> void:
	comprar_cenario("cenario2")

func _on_cenario_3_btn_pressed() -> void:
	comprar_cenario("cenario3")

func _on_cenario_4_btn_pressed() -> void:
	comprar_cenario("cenario4")

# --- Outras Funções do Script Original (Mantidas) ---

func _process(delta: float) -> void:
	pass 




func _on_aba_poderes_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_poderes.tscn")


func _on_aba_moedas_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_moedas.tscn")


func _on_aba_diamantes_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_diamantes.tscn")


func _on_sair_btn_pressed() -> void:
	get_tree().quit()


func _on_voltar_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
