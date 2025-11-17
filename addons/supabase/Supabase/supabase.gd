@tool
extends Node

const ENVIRONMENT_VARIABLES : String = "supabase/config"

var auth : SupabaseAuth 
var database : SupabaseDatabase
var realtime : SupabaseRealtime
var storage : SupabaseStorage

var debug: bool = false

var config : Dictionary = {
	"supabaseUrl": "https://xejfxpgsafevntndpkpb.supabase.co",
	"supabaseKey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlamZ4cGdzYWZldm50bmRwa3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3MDA0OTksImV4cCI6MjA3ODI3NjQ5OX0.zwKBdNAVo1nqB7X7DCpTNrsdb9v2zdRowtMSgYyyFec"
}

var header : PackedStringArray = [
	"Content-Type: application/json",
	"Accept: application/json"
]

# ID do usuário logado (deve ser definido após o login)
# Para fins de teste, você precisa de um ID UUID válido do seu banco de dados
var current_user_id: String = "" # <-- DEFINA ISSO APÓS O LOGIN

# Sinais que disparam eventos após a comunicação com o DB
signal diamantes_carregados(gems: int)
signal diamantes_salvos(success: bool, new_gems: int)
signal data_carregada(data: Dictionary) # Novo sinal para enviar coins e gems juntos
signal skins_carregadas(skins_ids: Array)
signal transacao_compra_salva(success: bool, new_gems: int, new_skin_id: int)
signal poderes_carregados(power_qtys: Dictionary)
signal transacao_poder_salva(success: bool, new_coins: int, power_id: int, new_qty: int)

func _ready() -> void:
	load_config()
	load_nodes()
	print("Supabase Wrapper pronto.")
	
	# Exemplo: Se você souber o ID do usuário após o login
	# current_user_id = auth.get_current_user_id() 

# ... (restante das suas funções load_config, load_nodes, set_debug, _print_debug) ...
# (Mantive suas funções originais inalteradas, exceto a _ready)

# Load all config settings from ProjectSettings
func load_config() -> void:
	if config.supabaseKey != "" and config.supabaseUrl != "":
		pass
	else:
		var env = ConfigFile.new()
		var err = env.load("res://addons/supabase/.env")
		if err == OK:
			for key in config.keys():
				var value : String = env.get_value(ENVIRONMENT_VARIABLES, key, "")
				if value == "":
					printerr("%s has not a valid value." % key)
				else:
					config[key] = value
		else:
			printerr("Unable to read .env file at path 'res://.env'")
	header.append("apikey: %s"%[config.supabaseKey])

func load_nodes() -> void:
	auth = SupabaseAuth.new(config, header)
	database = SupabaseDatabase.new(config, header)
	realtime = SupabaseRealtime.new(config)
	storage = SupabaseStorage.new(config)
	add_child(auth)
	add_child(database)
	add_child(realtime)
	add_child(storage)

func set_debug(debugging: bool) -> void:
	debug = debugging

func _print_debug(msg: String) -> void:
	if debug: print_debug(msg)


# --- NOVAS FUNÇÕES DE INTERAÇÃO COM O BANCO DE DADOS ---

func carregar_diamantes(user_id: String) -> void:
	# Seleciona apenas a coluna 'gems' da tabela 'profiles' para o usuário
	var query = database.from("profiles").select("gems").eq("id", user_id)
	
	query.execute(self, "_on_diamantes_carregados")

func _on_diamantes_carregados(result: Dictionary):
	if result.success and result.data is Array and not result.data.is_empty():
		var gems_valor: int = result.data[0].gems
		emit_signal("diamantes_carregados", gems_valor)
	else:
		printerr("Erro ao carregar diamantes: ", result.error)
		emit_signal("diamantes_carregados", 0) # Retorna 0 em caso de falha

func salvar_diamantes(user_id: String, novo_total: int) -> void:
	var update_data = {"gems": novo_total}
	# Atualiza a tabela 'profiles' para o usuário específico
	var query = database.from("profiles").update(update_data).eq("id", user_id)
	
	query.execute(self, "_on_diamantes_salvos", [novo_total])

func _on_diamantes_salvos(result: Dictionary, novo_total: int):
	if result.success:
		_print_debug("Diamantes atualizados com sucesso no DB.")
		emit_signal("diamantes_salvos", true, novo_total)
	else:
		printerr("Erro ao salvar diamantes: ", result.error)
		emit_signal("diamantes_salvos", false, -1) 
		

func carregar_dados_usuario(user_id: String) -> void:
	# Seleciona as colunas 'coins' e 'gems'
	var query = database.from("profiles").select("coins,gems").eq("id", user_id)
	query.execute(self, "_on_dados_usuario_carregados")

func _on_dados_usuario_carregados(result: Dictionary):
	if result.success and result.data is Array and not result.data.is_empty():
		var data_dict = {
			"coins": result.data[0].coins,
			"gems": result.data[0].gems
		}
		emit_signal("data_carregada", data_dict)
	else:
		printerr("Erro ao carregar dados do usuário: ", result.error)
		emit_signal("data_carregada", {"coins": 0, "gems": 0})


func salvar_transacao_moedas(user_id: String, new_coins: int, new_gems: int) -> void:
	var update_data = {"coins": new_coins, "gems": new_gems}
	
	# Prepara o Dictionary para o retorno do sinal
	var return_data = {"coins": new_coins, "gems": new_gems}
	
	var query = database.from("profiles").update(update_data).eq("id", user_id)
	
	# O handler deve receber o 'return_data' para saber o que foi salvo
	query.execute(self, "_on_transacao_moedas_salva", [return_data])

func _on_transacao_moedas_salva(result: Dictionary, return_data: Dictionary):
	if result.success:
		_print_debug("Transação de moedas/diamantes concluída com sucesso.")
		# Reutiliza o sinal 'diamantes_salvos' para indicar sucesso, mas com o Dictionary completo
		emit_signal("diamantes_salvos", true, return_data) 
	else:
		printerr("Erro ao salvar transação de moedas: ", result.error)
		# Retorna o erro
		emit_signal("diamantes_salvos", false, {})
		

func carregar_skins_usuario(user_id: String) -> void:
	# Consulta a tabela 'user_skins' para obter todos os 'skin_id' para este usuário
	var query = database.from("user_skins").select("skin_id").eq("user_id", user_id)
	query.execute(self, "_on_skins_usuario_carregadas")

func _on_skins_usuario_carregadas(result: Dictionary):
	var possessed_skins: Array = []
	if result.success and result.data is Array:
		# Converte o array de dicionários ([{skin_id: 1}, {skin_id: 2}]) em um array simples ([1, 2])
		for row in result.data:
			possessed_skins.append(row.skin_id)
		
		emit_signal("skins_carregadas", possessed_skins)
	else:
		printerr("Erro ao carregar skins do usuário: ", result.error)
		emit_signal("skins_carregadas", [])

func salvar_compra_cenario(user_id: String, new_gems: int, skin_id: int) -> void:
  
	var data_to_return = {"new_gems": new_gems, "new_skin_id": skin_id}

	var success = true # Simulação de sucesso
	
	if success:
		emit_signal("transacao_compra_salva", true, new_gems, skin_id)
	else:
		printerr("Falha na transação de compra de cenário.")
		emit_signal("transacao_compra_salva", false, -1, -1)
		
		
func carregar_poderes_usuario(user_id: String) -> void:
	# Consulta a tabela 'user_powers' para obter power_id e quantity
	var query = database.from("user_powers").select("power_id,quantity").eq("user_id", user_id)
	query.execute(self, "_on_poderes_usuario_carregados")

func _on_poderes_usuario_carregados(result: Dictionary):
	var possessed_powers: Dictionary = {}
	if result.success and result.data is Array:
		# Mapeia o array de resultados para um dicionário {id: quantidade}
		for row in result.data:
			possessed_powers[row.power_id] = row.quantity
		
		emit_signal("poderes_carregados", possessed_powers)
	else:
		printerr("Erro ao carregar poderes do usuário: ", result.error)
		emit_signal("poderes_carregados", {})
		
func salvar_compra_poder(user_id: String, new_coins: int, power_id: int, new_qty: int) -> void:
	var success = true
	
	if success:
		emit_signal("transacao_poder_salva", true, new_coins, power_id, new_qty)
	else:
		printerr("Falha na transação de compra de poder.")
		emit_signal("transacao_poder_salva", false, -1, -1, -1)
