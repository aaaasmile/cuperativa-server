# Cuperativa-server

Ho installato ruby 3.2.0 in versione windows con devkit. Mysys2 l'ho riciclato da quello
già installato, ma ho fatto un update usando la finestra cmd finale (opzioni 1,2,3 in serie).
Per avere una powershell che funziona con ruby si usa: 

    $env:path = "D:\ruby\ruby_3_2_1\bin;" + $env:path

## Gem necessari
Il codice di partenza è alquanto datato, ma  l'istallazione dei gems procede come segue:

- gem install daemons
- gem install eventmachine (nota che per questo gem è necessario MSYS2)
- gem install activerecord

Versioni installate:
- daemons-1.4.1
- eventmachine-1.2.7
- activerecord-7.0.4.1

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
