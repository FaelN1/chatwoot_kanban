@echo off
echo Corrigindo erro do Git...

rem Remove o arquivo do índice Git
git rm --cached .circleci/setup_chatwoot.sql

rem Certifica-se que o diretório existe
mkdir -p .circleci

rem Adiciona o arquivo novamente
git add .circleci/setup_chatwoot.sql

echo Arquivo corrigido! Tente fazer o commit novamente:
echo git commit -m "Fix setup_chatwoot.sql file"
