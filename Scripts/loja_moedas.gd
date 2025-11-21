extends Control

# Assumindo que SupabaseClient é um Singleton (Autoload)
const Supabase = preload("res://addons/supabase/Supabase/supabase.gd") # AJUSTE O CAMINHO
var supabase_client: Node = null

# Variáveis de estado local que refletem os valores do banco de dados
var total_moedas: int = 0
var total_diamantes: int = 0
var user_id: String = ""

# Referências para as Labels
@onready var label_moedas: Label = $LabelMoedas 
@onready var label_diamantes: Label = $LabelDiamantes 


# --- Estrutura dos Pacotes de Compra (Diamantes por Moedas) ---
const PACKAGES = {
	"moeda1": {"coins": 100, "cost_gems": 5},
	"moeda2": {"coins": 500, "cost_gems": 20},
	"moeda3": {"coins": 2000, "cost_gems": 60},
	"moeda4": {"coins": 10000, "cost_gems": 250},
}


# ==========================================================
# --- FUNÇÕES DE ATUALIZAÇÃO DA UI ---
# ==========================================================

func _atualizar_display_moedas():
	label_moedas.text = str(total_moedas)

func _atualizar_display_diamantes():
	label_diamantes.text = str(total_diamantes)


# ==========================================================
# --- INICIALIZAÇÃO E CONEXÃO COM O SINGLETON ---
# ==========================================================

func _ready() -> void:
	# 1. Obter a referência do Singleton e conectar os sinais
	supabase_client = get_node("/root/SupabaseClient") # Ajuste o nome do Autoload se for diferente
	
	if is_instance_valid(supabase_client):
		# Conexão para carregar os dois montantes
		supabase_client.data_carregada.connect(_on_dados_iniciais_carregados) # NOVO SINAL NECESSÁRIO!
		
		# Conexão para salvar (usaremos o mesmo sinal de 'diamantes_salvos' do seu script)
		supabase_client.diamantes_salvos.connect(_on_transacao_salva_no_db)
		
		# 2. Obter o ID do usuário
		user_id = supabase_client.current_user_id
		
		if user_id.is_empty():
			printerr("ERRO: ID do usuário vazio.")
			_atualizar_display_moedas()
			_atualizar_display_diamantes()
		else:
			# 3. Inicia o carregamento de AMBOS os dados
			# NOTA: Você precisará de uma nova função no Singleton para carregar 'coins' e 'gems' de uma vez.
			supabase_client.carregar_dados_usuario(user_id) 
	else:
		printerr("ERRO: O Singleton SupabaseClient não está carregado.")

# ==========================================================
# --- LOGICA DE COMPRA ---
# ==========================================================

func comprar_pacote_moedas(package_key: String):
	var pacote = PACKAGES[package_key]
	var custo_diamantes = pacote.cost_gems
	var ganho_moedas = pacote.coins

	if total_diamantes < custo_diamantes:
		print("COMPRA FALHOU: Saldo insuficiente de diamantes (Requer:", custo_diamantes, ").")
		return

	# Se o saldo for suficiente:
	# 1. Calcula os novos totais
	var novo_total_diamantes = total_diamantes - custo_diamantes
	var novo_total_moedas = total_moedas + ganho_moedas
	
	# 2. Atualiza a UI imediatamente para feedback rápido (opcional, pode ser feito após o DB)
	total_diamantes = novo_total_diamantes
	total_moedas = novo_total_moedas
	_atualizar_display_diamantes()
	_atualizar_display_moedas()

	# 3. Envia a transação de atualização para o DB
	# NOTA: Você precisará de uma nova função no Singleton para fazer um UPDATE MULTIPLO.
	print("Enviando transação de compra para o DB...")
	supabase_client.salvar_transacao_moedas(user_id, novo_total_moedas, novo_total_diamantes)

# ==========================================================
# --- HANDLERS DE SINAIS (RESPOSTAS DO SINGLETON) ---
# ==========================================================

# Handler para o novo sinal (assume que o Singleton envia {coins: X, gems: Y})
func _on_dados_iniciais_carregados(data: Dictionary):
	total_moedas = data.coins
	total_diamantes = data.gems
	_atualizar_display_moedas()
	_atualizar_display_diamantes()

# Handler para o salvamento da transação (usaremos o mesmo sinal 'diamantes_salvos' do script anterior)
func _on_transacao_salva_no_db(success: bool, data: Dictionary):
	if success:
		# Assumindo que o Singleton retorna os novos valores salvos
		total_moedas = data.coins
		total_diamantes = data.gems
		_atualizar_display_moedas()
		_atualizar_display_diamantes()
		print("Transação de moedas concluída e salva no DB!")
	else:
		# Se falhar, recarregamos os dados do banco ou notificamos o usuário
		print("Falha ao salvar a transação. Recarregando dados...")
		supabase_client.carregar_dados_usuario(user_id) # Recarrega para obter o estado correto


# --- Sinais dos Botões (Conectados) ---

func _on_moeda_1_btn_pressed() -> void:
	comprar_pacote_moedas("moeda1")

func _on_moeda_2_btn_pressed() -> void:
	comprar_pacote_moedas("moeda2")

func _on_moeda_3_btn_pressed() -> void:
	comprar_pacote_moedas("moeda3")

func _on_moeda_4_btn_pressed() -> void:
	comprar_pacote_moedas("moeda4")

# --- Outras Funções do Script Original (Mantidas) ---

func _on_aba_poderes_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_poderes.tscn")


func _on_aba_cenarios_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_cenarios.tscn")


func _on_aba_diamantes_pressed() -> void:
	get_tree().change_scene_to_file("res://loja_diamantes.tscn")


func _on_sair_btn_pressed() -> void:
	get_tree().quit()


func _on_voltar_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
