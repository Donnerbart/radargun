BATCH_END_TIME=$(date +%s)

echo
echo ===============================================================
echo Total batch runtime: $(echo "${BATCH_END_TIME} - ${BATCH_START_TIME}" | bc) seconds
echo ===============================================================