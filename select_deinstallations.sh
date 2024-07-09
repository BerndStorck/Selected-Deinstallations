#!/bin/bash
#
# select_deinstallations.sh
#

# input_file="$1"
package_name="$1"

get_package_description () {
    local package="$1"
    local description
    description="$(LANG=C aptitude show "$package")"
    
    extract_depends "$description"
}


extract_depends () {
    local description="$1"
    local depends
    depends="$(grep -m 1 "^Depends:" <<< "$description" | cut -d ':' -f 2)"
 
    if [ -n "$depends" ]; then
        # Remove version data like '(>= 1.20.2)' and the characters ',' and '|',
        # also replace multiple spaces by a single space:
        echo "$(sed -e 's/([^)]*)//g' -e 's/[,|]//g' -e 's/  / /g' <<< "$depends")"
    else
        echo "No Depends section found." > /dev/stderr
        exit 1
    fi
}


cleanup () {
  rm -fv not_installed installed_packages purged_packages removed_packages
}


if ! command -v aptitude &> /dev/null; then
  echo "aptitude wird benötigt; es wird nun installiert:"
  sudo apt-get update
  if ! sudo apt-get install aptitude; then
    echo "FEHLER: aptitude konnte nicht installiert werden." 
    echo "Das Programm terminiert daher jetzt unverrichteter Dinge."
    exit 2
  fi
fi

depends="$(get_package_description "$package_name")"

trap cleanup EXIT
cleanup

# Paketliste aus der Datei lesen:
while read -r line; do
  for package in $line; do
    if dpkg -l | grep -q "^ii  $package"; then  # Prueft, ob das Paket installiert ist

      echo -e "$package ist installiert.\n"
      echo "$package" >> installed_packages
      aptitude show "$package" # Paketinformationen anzeigen

      choice=
      read -r -p 'Möchten Sie das Paket behalten oder deinstallieren? (b/d): ' choice < /dev/tty

      if [ "$choice" = 'b' ]; then
        echo "Ok, das Paket $package wird behalten."

      elif [ "$choice" = 'd' ]; then
        echo "$package wird deinstalliert:"

        read -rp "Purge oder nur remove? (p|r): " < /dev/tty
        [ "${REPLY,,}" = 'p' ] && option="--purge" || option=""

        # Paket deinstallieren:
        if sudo apt-get remove "$option" "$package"; then
          if [ "$option" = '--purge' ]; then
            echo "$package " >> purged_packages
          else
            echo "$package " >> removed_packages
          fi
        fi
      else
        echo "Ungültige Eingabe: Das Paket $package wird behalten."
      fi
    else
      echo "$package ist nicht installiert."
      echo "$package " >> not_installed
    fi
  done
done <<< "$depends"

{
echo -e "DEINSTALLATIONSBERICHT"

if [ -f not_installed ]; then
  echo "Nicht installierte Pakete aus der Liste:"
  cat not_installed
fi

if [ -f installed_packages ]; then
  echo -e "\nBisher installierte Pakete aus der Liste:"
  cat installed_packages
fi

if [ -f removed_packages ]; then 
  echo -e "\nPakete die deinstalliert wurden (remove):"
  cat removed_packages
fi

if [ -f purged_packages ]; then 
  echo -e "\nPakete die inklusive ihrer Konfigurationsdateien deinstalliert wurden (purge):"
  cat purged_packages
fi
} > deinstallation.log

exit 0
