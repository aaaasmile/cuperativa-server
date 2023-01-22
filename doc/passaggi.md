# Cuperativa-server
La motivazione di questo progetto è quella di avere un gestore dei giochi di 
carte della cuperativa via tcp. L'idea è di avere i robots che si collegano 
a questo server come nel 2012 (progetto D:\old_stuff\PC_Jim_2016\Projects\ruby\Cuperativa_All_version_svn\cuperativa0508_railsplayground_last), 
mentre la parte che gestisce tutto il resto viene gestita in golang nel progetto 
D:\Projects\go-lang\cup-service\cup-service. Il client è nel browser e si collega con cup-service.
cup-service gestisce tutti websocket, le risorse in javascript e altri collegamenti al db
che non siano gestiti da questo server. Questo per evitare di riscrivere in go tutta la logica
dei giochi che è già pronta in ruby. 
La parte che gestisce l'accesso al database è quella che ho cambiato nel progetto
sinatra D:\scratch\sinatra\cup_sinatra_local\middlewares\cup_srv\database

## Installazione
Ho installato ruby 3.2.0 in versione windows con devkit. Mysys2 l'ho riciclato da quello
già installato, ma ho fatto un update usando la finestra cmd finale (opzioni 1,2,3 in serie).
Per avere una powershell che funziona con ruby si usa: 

    $env:path = "D:\ruby\ruby_3_2_0\bin;" + $env:path

## Gem necessari
Il codice di partenza è alquanto datato, ma  l'istallazione dei gems procede come segue:

- gem install daemons
- gem install eventmachine (nota che per questo gem è necessario MSYS2)
- gem install debug (per avere il debugger in VS Code)
- gem install pg

Versioni installate:
- daemons-1.4.1
- eventmachine-1.2.7

## Visual Code
Ho installato due extension per ruby. La prima è Ruby e la seconda è Rufo-Ruby formatter.
Nota che ch rufo è un gem che va installato a parte con:

    gem install rufo
Poi nei sttings delle due extensions vanno messi i path assoluti di rufo.bat e ruby.exe.
Per fare andare il formatter, visual code l'ho dovuto far ripartire.

## Start Server
In windows, nella root directory del progetto, puoi lanciare

    .\server\runserver.ps1

## log4r
Il gem log4r-1.1.10 che ho installato all'inizio è troppo datato e non è compatibile con 
ruby 3.2.0. Per cui l'ho incluso in questo progetto e l'ho modificato per farlo funzionare.
Su Github ci sono dei pull request che lo fanno andare a modo (https://github.com/colbygk/log4r/pull/67/files).

## debugger
Ho usato l'extension VsCode rdbg Ruby dove tutti i parametri del caso vanno messi nel file launch.json.
Però il debugger nell'EventMachine ha un crash e quindi non credo che nel server sia utilizzabile.
Anche nella versione precedente, se non ricordo male, il server non funzionava con il debugger.

## Database postgresql (pg)
In questa versione sono passato al database Postgres. Per installare il gem si usa

    gem install pg
Viene però  richiesta la dipendenza della libreria in C/C++ postgresql
che nel mio sistema Msys2 non è installata e non è stata richiesta durante il setup di ruby con devkit.
Nota che in powershell mi compare la seguente informazione:

    Please install libpq or postgresql client package like so:
    ridk exec sh -c "pacman -S ${MINGW_PACKAGE_PREFIX}-postgresql"
Ma non mi ha funzionato. Ho invece aperto MySys2 ed ho installato la libreria mancante con:

    pacman -S mingw-w64-ucrt-x86_64-postgresql
Nota che uso i pacchetti di ucrt e solo quelli. Al termine dell'update l'installazione del gem pg
ha funzionato.

### Restore del db
Ho un backup fatto sul laptop che non riesco a fare il restore su MiniToro (files in D:\scratch\postgres\cupuserdatadb).
Per prima cosa ho creato il database cupuserdatadb usando pgAdmin4. Poi ho aggiunto l'utente cup_user
come ho fatto nella corsa (ReadmeCorsaRacepicker.txt) usando powershell:

    PS C:\Program Files\PostgreSQL\15\bin> .\createuser.exe --username=postgres --login -P cup_user
La password la vedi in options.yaml che non è nella repository.
Poi ho lanciato le seguenti SQL:

    GRANT ALL PRIVILEGES ON DATABASE cupuserdatadb TO cup_user;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cup_user;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cup_user;

Come riferimento vedi il porting che ho fatto con sinatra:
D:\scratch\sinatra\cup_sinatra_local 
qui si trova un server che usa pg.

## Active Record
Ho tolto il riferimento ad Active Record in quanto non riesco a farlo andare 
mentre nel progetto D:\scratch\sinatra\cup_sinatra_local\middlewares\cup_srv\database
faccio tutto usando SQL in pg. 
Allo stesso modo però ricevo l'errore:

    Connector error(connection to server at "127.0.0.1", port 5432 failed: server closed the connection unexpectedly
            This probably means the server terminated abnormally
            before or while processing the request.