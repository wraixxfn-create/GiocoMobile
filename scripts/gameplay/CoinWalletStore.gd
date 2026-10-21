class_name CoinWalletStore
extends RefCounted
## Salvataggio locale minimale del saldo permanente delle monete.
## ConfigFile scrive sotto user://, quindi il dato resta fuori dal progetto e
## sopravvive alla chiusura e al riavvio del gioco.

const SECTION: String = "wallet"
const BALANCE_KEY: String = "permanent_coins"

var save_path: String


func _init(path: String = GameConfig.COIN_SAVE_PATH) -> void:
	save_path = path


## Al primo avvio (file assente) restituisce zero e crea un salvataggio valido.
## Un file non leggibile/corrotto viene trattato in modo sicuro come saldo zero.
func load_balance() -> int:
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error == ERR_FILE_NOT_FOUND:
		save_balance(0)
		return 0
	if error != OK:
		push_warning("Salvataggio monete non leggibile (%s): saldo inizializzato a zero." % save_path)
		save_balance(0)
		return 0

	var value: Variant = config.get_value(SECTION, BALANCE_KEY, 0)
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		push_warning("Saldo monete non valido in %s: saldo inizializzato a zero." % save_path)
		return 0
	return maxi(int(value), 0)


## Salva il saldo in modo sincrono: una moneta è già permanente al momento
## dell'aggiornamento dell'HUD e non dipende da una successiva schermata shop.
func save_balance(balance: int) -> bool:
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		# Se il file è danneggiato, lo sostituiamo con una configurazione valida.
		push_warning("Salvataggio monete danneggiato (%s): verrà ricreato." % save_path)
		config = ConfigFile.new()

	config.set_value(SECTION, BALANCE_KEY, maxi(balance, 0))
	var save_error := config.save(save_path)
	if save_error != OK:
		push_warning("Impossibile salvare il saldo monete (%s), errore %d." % [save_path, save_error])
		return false
	return true
