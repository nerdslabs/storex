# Configuration

## Session library

You can change library which generate session id for stores. Module needs to have **generate/0** method.

```
config :stex, :session_id_library, Ecto.UUID
```