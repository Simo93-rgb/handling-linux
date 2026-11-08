# Contribuire e installare

La repository è organizzata per componente. Ogni modifica funzionale deve
restare nella directory del componente interessato:

```text
components/<nome>/
├── README.md
├── docs/
├── config/
├── scripts/
├── tests/
└── systemd/
```

Non tutte le directory sono necessarie: vanno create solo quando il componente
le usa. Le varianti di piattaforma sono in `scripts/cachyos/`,
`scripts/bazzite/` o `systemd/{cachyos,bazzite}/`.

## Regole

1. Aggiorna il README del componente quando cambiano installazione o
   prerequisiti.
2. Mantieni i nomi specifici: evita directory generiche come `system/` o file
   come `flowchart.mmd`.
3. Usa percorsi relativi nei link Markdown.
4. Non inserire credenziali, token o percorsi personali.
5. Non usare comandi Arch sull'host Bazzite: usa il profilo e il container
   indicati dalla guida.
6. Esegui il controllo globale:

```bash
bash scripts/checks/check_repository.sh
```

## Spostare un componente

Quando sposti un file, aggiorna nello stesso cambiamento:

- il README del componente;
- i link delle guide;
- i workflow GitHub;
- i controlli strutturali;
- i diagrammi Mermaid collegati.

Prima di un commit verifica che non esistano riferimenti ai vecchi percorsi con
`rg 'scripts/|config/|docs/'`.

## Installazione

Le guide nei componenti sono la fonte di verità. Leggi prima il profilo
piattaforma, poi il README dell'area e infine la guida dettagliata.
