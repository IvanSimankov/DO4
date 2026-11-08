#!/usr/bin/env bash

readonly -a HTTP_CODES=(200 201 400 401 403 404 500 501 502 503)
readonly -a HTTP_METHODS=(GET POST PUT PATCH DELETE)

readonly -a USER_AGENTS=(
    'Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0'
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36'
    'Opera/9.80 (X11; Linux x86_64) Presto/2.12.388 Version/12.16'
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
    'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)'
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0'
    'Googlebot/2.1 (+https://www.google.com/bot.html)'
    'curl/8.5.0'
)
readonly -a URL_PATHS=(
    '/' '/index.html' '/login' '/logout' '/products' '/catalog'
    '/api/v1/users' '/api/v1/items' '/api/v1/orders'
    '/search' '/about' '/contact' '/robots.txt' '/static/app.js' '/images/logo.png'
)
readonly -a REFERERS=(
    '-'
    'https://example.org/'
    'https://example.org/products'
    'https://search.example.org/?q=monitoring'
)

random_int() {
    local min="$1" max="$2"
    REPLY=$((min + (((RANDOM << 15) | RANDOM) % (max - min + 1))))
}

random_ipv4() {
    local a b c d
    random_int 1 223; a="$REPLY"
    random_int 0 255; b="$REPLY"
    random_int 0 255; c="$REPLY"
    random_int 1 254; d="$REPLY"
    IP_ADDRESS="$a.$b.$c.$d"
}

random_request_url() {
    local index id
    random_int 0 $((${#URL_PATHS[@]} - 1)); index="$REPLY"
    REQUEST_URL="${URL_PATHS[index]}"

    # Для части запросов добавляем случайный query-параметр.
    random_int 0 3
    if (( REPLY == 0 )); then
        random_int 1 99999; id="$REPLY"
        REQUEST_URL="${REQUEST_URL}?id=${id}"
    fi
}

# Формируем ровно одну строку combined log format:
# IP - USER [DD/Mon/YYYY:HH:MM:SS +ZZZZ] "METHOD URL HTTP/1.1" STATUS BYTES "REFERER" "AGENT"
print_log_entry() {
    local log_day="$1" time_of_day="$2" utc_offset="$3"
    local status method agent referrer bytes index

    random_ipv4
    random_request_url

    random_int 0 $((${#HTTP_CODES[@]} - 1)); status="${HTTP_CODES[REPLY]}"
    random_int 0 $((${#HTTP_METHODS[@]} - 1)); method="${HTTP_METHODS[REPLY]}"
    random_int 0 $((${#USER_AGENTS[@]} - 1)); agent="${USER_AGENTS[REPLY]}"
    random_int 0 $((${#REFERERS[@]} - 1)); referrer="${REFERERS[REPLY]}"
    random_int 0 65535; bytes="$REPLY"

    printf '%s - - [%s:%s %s] "%s %s HTTP/1.1" %s %s "%s" "%s"\n' \
        "$IP_ADDRESS" "$log_day" "$time_of_day" "$utc_offset" \
        "$method" "$REQUEST_URL" "$status" "$bytes" "$referrer" "$agent"
}
