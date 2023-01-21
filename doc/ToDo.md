## TODO
- Il collegameto di cupservice va fatto in modo proxy, vale a dire ha una gestione multipla 
di connessioni
- collegamento al database con pg
- gestione tempo di gioco sul server: tempo max giocata, tempo max mano....
- Quando un giocatore ha abbandonato il tavolo, bisognerebbe fare in modo
    che altri giocatori raggiungano il tavolo senza che tutti lascino il tavolo
    (utile se i giocatori sono >= 2).
- testare in modo automatico il gioco online

## Tempo sul server
La scopetta è implementata come:
5 secondi per effettuare una mano, 30 secondi di tempo complessivi per la
giocata.
In cuperativa si puo usare il principio come in scacchi il 30/5.
- Implementazione sul server: una procedura che ogni 2 secondi fa il check
della lista dei giocatori in attesa. Se il tempo a disposizione è finito,
viene mandato un comando all'altro giocatore che puo' vincere per time forfait.
Occore pero' mandare, quando un giocatore ha giocato, anche il tempo rimanente
sul server. Il tempo si puo' misurare in modo molto preciso usando time stamp
ad ogni azione. Il check del server nel time slot di 2 secondi, serve solo
per stabilire se il tempo e' finito. [??? NO]
Il server non deve fare il check del client. Basta che memorizzi il time stamp
del comando quando il client deve giocare. E' l'avversario che monitora il tempo
dell'altro giocatore e se vede che il tempo è scaduto, richiede al server il 
forfait per il tempo. A questo punto il server, usando il suo time stamp
fa un controllo e in caso positivo assegna la vittoria a tavolino per il timeout.
Quando un giocatore gioca, il server manda anche un timestamp a tutti i clients
per sincronizzare il tempo.

## Versioni future

- Invito sull'utente ad una partita
  * implementare i comandi pg_invite... sul 
    * client
    * server
- Lista nera per utente, escluso ospitexx
- Bavaglio chat
- I robot possono essere implementati in un solo file dove tutte le classi sono presenti
     in quanto la class può contenere solo 3 linee: alg name, core name 
- Database: mettere la colonna :last_opponents in tutte le classifiche per limitare
 l'assegnamento di punti contro gli stessi avversari, aggiungere anche la colonna
abbandoni e togliere dalla mariazza e briscola la colonna segni_tied
- giocatore che visualizza un altra partita come spettatore. Ho già iniziato
l'implementazione con il tab che è solo stato reso invisibile. 
- reconnect: riprende il gioco da dove era stato sospeso
      - Iniziato con la briscola.



