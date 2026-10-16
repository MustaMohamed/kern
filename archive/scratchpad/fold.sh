eval "$(sed -n '/^_G16_LONG_S=/p;/^_G16_KELVIN=/p' hooks/guards/g16-state.sh)"
eval "$(sed -n '/^_g16_fold()/,/^}/p' hooks/guards/g16-state.sh)"
for s in $'prompt-\305\277ubmit' $'hoo\342\204\252s' $'\340\305\277x' $'\342\204\305\277x' $'\360\237\305\277x' $'\305\305\277x' $'\342\342\204\252x' $'a\305\277\342\204\252b'; do
  _g16_fold "$s"; printf '%s ' "$(printf '%s' "$_G16_F" | od -An -c | tr -s ' ')"; echo
done
