#!/bin/bash
####################################################################################################
#    プログラム名  :  特定のテーブルに対して統計情報の更新(ANALYZE)を行います。
#    ファイル名    :  postgres_table_analyze.sh
#    作成者        :  
#    作成日        :  2025/03/27
#    備考          :  
#    変更履歴      :
#
#    日付        更新者    内容
#    2025/03/27  xxxxx     新規作成
#
#    引数          :  $1(例 postgres_table_analyze_test_db01_test_table01.conf)
#    戻り値        :  0(正常)
#                  :  1(異常)
#    使用例        :  ./postgres_table_analyze.sh postgres_table_analyze_test_db01_test_table01.conf
####################################################################################################
##################################################
# 関数定義
##################################################
#-------------------------------------------------
# 関数名  :  エラーハンドリング
# 機能    :  実行結果の戻り値と正常系・異常系メッセージを受取ります。
#            実行結果の戻り値が0の場合は正常系メッセージを表示します。
#            実行結果の戻り値が0以外の場合は異常系メッセージを表示します。
# 引数    :  $1(コマンドの戻り値)
#            $2(正常系メッセージ)
#            $3(異常系メッセージ)
#-------------------------------------------------
function proc_err_handling() {
    if [[ "$1" -eq 0 ]]; then
        # 正常系メッセージをコンソールとログファイルに出力して戻り値0を返す
        echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] $2" 2>&1 | tee -a "${LOG}"
        return 0
    else
        # システムログにエラーを通知
        logger -i -p user.err "[${HOST_NAME}] Monitoring notification code [${SCRIPT_NAME}.sh] Error code [$3]"
        # 異常系メッセージをコンソールとログファイルに出力して戻り値1を返す
        echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] $3" 2>&1 | tee -a "${LOG}"
        return 1
    fi
}

#-------------------------------------------------
# 関数名  :  特定テーブル統計情報更新(ANALYZE)
# 機能    :  特定のテーブルに対して統計情報の更新(ANALYZE)を行います。
# 引数    :
#-------------------------------------------------
function proc_postgres_tbl_analyze() {
    echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ${MSG_START_TBL_ANALYZE}" 2>&1 | tee -a "${LOG}"
    # クエリの実行
    echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ANALYZE VERBOSE ${DB_SCHEMA}.${DB_TABLE};"
    psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_HOST} -p ${DB_PORT} -c "ANALYZE VERBOSE ${DB_SCHEMA}.${DB_TABLE};" 2>&1 | tee -a "${LOG}"
    CMD_RC=${PIPESTATUS[0]}
    # エラーハンドリング関数呼出
    proc_err_handling "${CMD_RC}" "${MSG_SUCCESS_TBL_ANALYZE}" "${MSG_FAILURE_TBL_ANALYZE}"
}

##################################################
# 前処理
##################################################
#-------------------------------------------------
# 共通パラメータ取得
#-------------------------------------------------
#COMMON_CONF="/var/lib/pgsql/work/git/sh/bash/postgres/analyze/conf/common.conf"
COMMON_CONF="conf/common.conf"
. "${COMMON_CONF}"

#-------------------------------------------------
# 特定パラメータ取得
#-------------------------------------------------
#DATABASE_CONNECT_CONF="/var/lib/pgsql/work/git/sh/bash/postgres/analyze/conf/$1"
DATABASE_CONNECT_CONF="conf/$1"
. "${DATABASE_CONNECT_CONF}"

##-----------------------------------------------
## 共通パラメータ取得確認(デバック用途)
##-----------------------------------------------
param=(
    DATE="${DATE}"
    SCRIPT_NAME="${SCRIPT_NAME}"
    LOG_DATE="${LOG_DATE}"
    LOG_PATH="${LOG_PATH}"
    LOG="${LOG}"
    LOG_DELETE="${LOG_DELETE}"
    HOST_NAME="${HOST_NAME}"
    EXECUTE_USER="${EXECUTE_USER}"
    MSG_START_TBL_ANALYZE="${MSG_START_TBL_ANALYZE}"
    MSG_SUCCESS_TBL_ANALYZE="${MSG_SUCCESS_TBL_ANALYZE}"
    MSG_FAILURE_TBL_ANALYZE="${MSG_FAILURE_TBL_ANALYZE}"
    MSG_EXECUTE_USER_NOT_EXIST="${MSG_EXECUTE_USER_NOT_EXIST}"
    MSG_SUCCESS_LOG_DELETE="${MSG_SUCCESS_LOG_DELETE}"
    MSG_FAILURE_LOG_DELETE="${MSG_FAILURE_LOG_DELETE}"
    MSG_START_THIS="${MSG_START_THIS}"
    MSG_SUCCESS_END_THIS="${MSG_SUCCESS_END_THIS}"
    MSG_FAILURE_END_THIS="${MSG_FAILURE_END_THIS}"
    DB_HOST="${DB_HOST}"
    DB_PORT="${DB_PORT}"
    DB_NAME="${DB_NAME}"
    DB_USER="${DB_USER}"
    DB_PASSWORD="${DB_PASSWORD}"
    DB_SCHEMA="${DB_SCHEMA}"
    DB_TABLE="${DB_TABLE}"
)

for i in "${param[@]}"; do
    echo $i
done

#-------------------------------------------------
# ログ格納ディレクトリ存在確認
#-------------------------------------------------
if [[ ! -d log ]]; then
    # ログ格納ディレクトリが存在しない場合は作成
    mkdir log
    echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ${MSG_MAKE_LOG_DIRECTORY}" 2>&1 | tee -a "${LOG}"
fi

#-------------------------------------------------
# 実行ユーザ存在確認
#-------------------------------------------------
WHOAMI=""
WHOAMI=$(cat /etc/passwd | grep ^${EXECUTE_USER} | awk -F : '{print $1}')
if [[ ! "${WHOAMI}" ]]; then
    # 実行ユーザが存在しない場合は異常終了
    echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ${MSG_EXECUTE_USER_NOT_EXIST}" 2>&1 | tee -a "${LOG}"
    exit 1
fi

# 全体処理開始
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ${MSG_START_THIS}" 2>&1 | tee -a "${LOG}"

##################################################
# 主処理
##################################################
# 環境変数としてパスワードを設定（簡易対応）
export PGPASSWORD=${DB_PASSWORD}

# クエリの実行
# 注意事項1
# ヒアドキュメント中で変数を使用する場合は終端文字(EOL)をそのまま使用してください。
# 終端文字(EOL)を'EOL'、"EOL"でクォートで囲むと変数の変換は抑止されます。
# またクエリのRCは取得できません。
# 注意事項2
# クエリを変数、配列に格納する場合は、''、""の囲いの扱いでクエリが正しく認識されない場合があります。
# クエリ実行後にRCを取得する場合は、-c オプションにクエリを指定してください。

# スキーマ名、テーブル名、テーブルオーナー、インデックス有無の表示
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname NOT LIKE 'pg_%' AND schemaname != 'information_schema';" 2>&1 | tee -a "${LOG}"
psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_HOST} -p ${DB_PORT} << EOL 2>&1 | tee -a "${LOG}"
  SELECT schemaname, tablename, tableowner, hasindexes FROM pg_tables WHERE schemaname NOT LIKE 'pg_%' AND schemaname != 'information_schema';
EOL

# スキーマ名、テーブル名、インデックス名の表示
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] SELECT schemaname, tablename, indexname FROM pg_indexes WHERE schemaname NOT LIKE 'pg_%' AND schemaname != 'information_schema';" 2>&1 | tee -a "${LOG}"
psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_HOST} -p ${DB_PORT} << EOL 2>&1 | tee -a "${LOG}"
  SELECT schemaname, tablename, indexname FROM pg_indexes WHERE schemaname NOT LIKE 'pg_%' AND schemaname != 'information_schema';
EOL

# 特定テーブル統計情報更新(ANALYZE)関数呼出
proc_postgres_tbl_analyze
FUNC_RC="$?"
if [[ "${FUNC_RC}" != 0 ]]; then
    echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ${MSG_FAILURE_END_THIS}" 2>&1 | tee -a "${LOG}"
    # 異常終了
    exit 1
fi

# OID、インデックス名、インデックスページ数の表示
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] SELECT c.oid, c.relname AS index_name, c.relpages AS index_pages, n.nspname AS schema_name, c.relkind, c.reltablespace FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname != 'information_schema';" 2>&1 | tee -a "${LOG}"
psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_HOST} -p ${DB_PORT} << EOL  2>&1 | tee -a "${LOG}"
  SELECT c.oid, c.relname AS index_name, c.relpages AS index_pages, n.nspname AS schema_name, c.relkind, c.reltablespace FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname != 'information_schema';
EOL

# スキーマ名、テーブル名、インデックス名、インデックスサイズとインデックス見積もりサイズの表示
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] SELECT s.schemaname AS schema_name, s.relname AS table_name, c.relname AS index_name, pg_size_pretty(pg_relation_size(c.oid)) AS index_size, c.relpages AS total_pages, (c.relpages * 8192) AS estimated_size FROM pg_class c JOIN pg_stat_user_indexes s ON c.oid = s.indexrelid WHERE c.relname = 'idx_id01';" 2>&1 | tee -a "${LOG}"
psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_HOST} -p ${DB_PORT} << EOL  2>&1 | tee -a "${LOG}"
  SELECT s.schemaname AS schema_name, s.relname AS table_name, c.relname AS index_name, pg_size_pretty(pg_relation_size(c.oid)) AS index_size, c.relpages AS total_pages, (c.relpages * 8192) AS estimated_size FROM pg_class c JOIN pg_stat_user_indexes s ON c.oid = s.indexrelid WHERE c.relname = 'idx_id01';
EOL

# テーブルの不要レコード数、統計情報更新日時の表示
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] SELECT * FROM pg_stat_user_tables;" 2>&1 | tee -a "${LOG}"
psql -U ${DB_USER} -d ${DB_NAME} -h ${DB_HOST} -p ${DB_PORT} << EOL  2>&1 | tee -a "${LOG}"
  \x
  SELECT * FROM pg_stat_user_tables;
EOL

# 環境変数として設定したパスワードをクリア
unset PGPASSWORD

##################################################
# 後処理
##################################################
#-------------------------------------------------
# 特定日数を経過したログの削除
#-------------------------------------------------
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ${LOG_DELETE} 日以上経過したログの削除を開始します。" 2>&1 | tee -a "${LOG}"
find ${LOG_PATH} -mtime +${LOG_DELETE} -name *.log | xargs rm -f
CMD_RC=$(echo $?)
# エラーハンドリング関数呼出
proc_err_handling "${CMD_RC}" "${MSG_SUCCESS_LOG_DELETE}" "${MSG_FAILURE_LOG_DELETE}"

# 全体処理正常終了
echo "$(date +"%Y/%m/%d %H:%M:%S")" "[${HOST_NAME}] ${MSG_SUCCESS_END_THIS}" 2>&1 | tee -a "${LOG}"
# aws sns publish --topic-arn "${SNS_TOPIC_ARN}" --subject "${SNS_SUB_SUCCESS}" --message "${MSG_SUCCESS_END_THIS}" 2>&1 | tee -a "${LOG}"

exit 0
