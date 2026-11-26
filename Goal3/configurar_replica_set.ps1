# Executar uma vez no PowerShell como Administrador.
$ErrorActionPreference = "Stop"
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Abra o PowerShell como Administrador e execute novamente."
}

$configPath = "D:\develop\MongoDB\Server\8.2\bin\mongod.cfg"
$python = Join-Path $env:LOCALAPPDATA "Programs\Python\Python314\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
    throw "Indique neste script o caminho do Python que tem pymongo instalado."
}
& $python -c "import pymongo"
if ($LASTEXITCODE -ne 0) {
    throw "Instale pymongo neste Python antes de continuar."
}

$original = [IO.File]::ReadAllText($configPath)
if ($original -match '(?m)^replication:') {
    if ($original -notmatch '(?m)^\s+replSetName:\s*["'']?rs0["'']?\s*$') {
        throw "Já existe outra configuração de replica set. Verifique o ficheiro."
    }
} else {
    if ($original -notmatch '(?m)^#replication:\s*$') {
        throw "A secção de replication esperada não foi encontrada."
    }
    $backupPath = "$configPath.before-goal3.bak"
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Copy-Item -LiteralPath $configPath -Destination $backupPath
    }
    $updated = [regex]::Replace(
        $original, '(?m)^#replication:\s*$',
        "replication:`r`n  replSetName: rs0"
    )
    try {
        [IO.File]::WriteAllText($configPath, $updated, [Text.UTF8Encoding]::new($false))
        Restart-Service -Name MongoDB
        (Get-Service MongoDB).WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
    } catch {
        [IO.File]::WriteAllText($configPath, $original, [Text.UTF8Encoding]::new($false))
        if ((Get-Service MongoDB).Status -eq "Stopped") {
            Start-Service -Name MongoDB
        }
        throw
    }
}

$initialize = @"
from time import monotonic, sleep
from uuid import uuid4

from pymongo import MongoClient
from pymongo.errors import OperationFailure

with MongoClient("mongodb://localhost:27017/?directConnection=true",
                 serverSelectionTimeoutMS=5000) as client:
    try:
        client.admin.command("replSetGetStatus")
    except OperationFailure as error:
        if error.code != 94:
            raise
        client.admin.command("replSetInitiate", {
            "_id": "rs0",
            "members": [{"_id": 0, "host": "localhost:27017"}]
        })

    deadline = monotonic() + 60
    while not client.admin.command("hello").get("isWritablePrimary"):
        if monotonic() > deadline:
            raise TimeoutError("A eleicao do primary demorou mais de 60 segundos.")
        sleep(0.5)

# Abrir uma nova ligacao depois da inicializacao para detetar as sessoes.
with MongoClient("mongodb://localhost:27017/?replicaSet=rs0",
                 serverSelectionTimeoutMS=10000) as client:
    assert client.admin.command("hello").get("setName") == "rs0"

    # Confirmar as transacoes numa base temporaria com duas colecoes.
    test_name = "bda_transaction_check_" + uuid4().hex
    db = client[test_name]
    try:
        db.create_collection("a")
        db.create_collection("b")
        with client.start_session() as session:
            with session.start_transaction():
                db.a.insert_one({"_id": 1}, session=session)
                db.b.insert_one({"_id": 1}, session=session)
        assert db.a.count_documents({}) == db.b.count_documents({}) == 1

        with client.start_session() as session:
            session.start_transaction()
            db.a.insert_one({"_id": 2}, session=session)
            db.b.insert_one({"_id": 2}, session=session)
            session.abort_transaction()
        assert db.a.find_one({"_id": 2}) is None
        assert db.b.find_one({"_id": 2}) is None
        print("Replica set rs0 pronto. COMMIT e ROLLBACK verificados.")
    finally:
        client.drop_database(test_name)
"@
$initialize | & $python -
if ($LASTEXITCODE -ne 0) {
    throw "A inicializacao ou a verificacao falhou. Consulte a mensagem acima."
}
Write-Output "Reinicie o kernel do Goal 3 para renovar a ligacao."