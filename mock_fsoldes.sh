echo -e  "\n\n" > "$LOGDIR/mockfsoldes_log"

contador=0
while [ $contador -lt 6 ] ; do
#echo "FSOLDES running"
echo "mockfsoldes corriendo con PID: $$" >> "$LOGDIR/mockfsoldes_log"
contador=$(($contador + 1))
sleep 5
done
