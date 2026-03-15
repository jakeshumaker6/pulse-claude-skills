# Odoo 19 Development Gotchas

## XML Syntax Changes (vs Odoo 17/18)

- `category_id` field removed from `ir.module.module` — do not reference it in manifests
- `users` field on `res.groups` is no longer writable in data XML
- `numbercall` removed from `ir.cron` — remove from any cron XML records
- `<group>` tag inside search views is invalid — use `<filter>` instead

## Payment Provider Inline Forms

- Inline forms use **standalone templates**, NOT template inheritance
- Provider data record must set `inline_form_view_id` to reference the template
- Template is rendered via `t-call="{{inline_form_xml_id}}"`
- Web components can be loaded directly in the template (no assets bundle needed)

## JustiFi Payment Integration

- Web component token generated **WITHOUT** Sub-Account header
- Test card: `4242 4242 4242 4242`
