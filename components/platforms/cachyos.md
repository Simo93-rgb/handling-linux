# Profilo CachyOS / Arch Linux

Questo profilo conserva le implementazioni Fish e i flussi nativi Arch della
repository.

## Componenti supportati

- GameMode e segregazione CCD tramite gli script `.fish` in
  [`cpu-gaming/scripts/cachyos/`](../cpu-gaming/scripts/cachyos/).
- Kernel Linux-TKG e Proton-TKG con `makepkg`, `pacman` e, dove indicato,
  `paru`.
- Configurazione GRUB tramite `/etc/default/grub` e `grub-mkconfig`.
- Cache Hugging Face con `environment.d` e variabili universali Fish.

## Installazione

Le guide dei componenti restano la fonte di verità. Prima di eseguire uno
script verificare CPU, maschere CCD, percorsi locali e pacchetti disponibili.
