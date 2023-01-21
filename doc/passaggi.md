# Cuperativa-server

Ho installato ruby 3.2.0 in versione windows con devkit. Mysys2 l'ho riciclato da quello
già installato, ma ho fatto un update usando la finestra cmd finale (opzioni 1,2,3 in serie).
Per avere una powershell che funziona con ruby si usa: 

    $env:path = "D:\ruby\ruby_3_2_1\bin;" + $env:path

## Gem necessari
Il codice di partenza è alquanto datato, ma  l'istallazione dei gems procede come segue:

- gem install daemons
- gem install log4r
- gem install eventmachine (nota che per questo gem è necessario MSYS2)
- gem install activerecord

Versioni installate:
- daemons-1.4.1.gem
- log4r-1.1.10
- eventmachine-1.2.7
- activerecord-7.0.4.1