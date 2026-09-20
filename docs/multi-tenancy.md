# Fitting Janela into a multi tenant application

Janela holds no tenancy of its own. There is no tenant setting, no
default scope of ours on your models, and nothing to configure. The
engine asks your application two questions and does what it is told.

| Question | How your application answers | If it says nothing |
| --- | --- | --- |
| What may this request read? | `policy_scope(model)` on the controller Janela inherits | Nothing: it raises `Janela::Unscoped` |
| What owns a frame being created? | `janela_frame_owner` on the same controller | Nothing: a nil owner |

Both are ordinary methods on your `ApplicationController`, found by
duck typing. Pundit defines the first for you. Anything else, you
define in about five lines. ADR 019 has the reasoning for asking
rather than being configured: ownership is per-request state, and a
setting cannot hold it.

## What goes through your scope

Everything. There is no path through the engine that reads a record
without asking first:

- The index of frames, and each frame page.
- Every editing action on a frame or a pane, so another tenant's frame
  is a 404 to rename or delete as much as to read.
- Every pane's own query, on Janela's pages and inline in yours. The
  measure is calculated over `policy_scope(Order)`, not over `Order`.
- An ad hoc pane URL, which is the same query by another route.
- A snapshot, read through `policy_scope(Janela::Snapshot)`.

A pane rendered inline in your own page runs in your request, so the
same scope applies there as in the engine's controllers. Nothing is
calculated in a background context where the current tenant would have
gone missing.

## With Pundit

Write a policy for Janela's own record. The class name is namespaced,
because the model is:

```ruby
# app/policies/janela/frame_policy.rb
module Janela
  class FramePolicy < ApplicationPolicy
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(owner: Current.account)
      end
    end
  end
end
```

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  private
    def janela_frame_owner
      Current.account
    end
end
```

Your own models keep the policies they already have. Janela calls
`policy_scope(Order)` and gets whatever `OrderPolicy::Scope` returns.

## With acts_as_tenant

Your own models are already scoped, so the only thing Janela needs
told about is its own tables. Define `policy_scope` as the adapter:

```ruby
class ApplicationController < ActionController::Base
  set_current_tenant_through_filter
  before_action :set_tenant

  private
    def policy_scope(model)
      case model.name
      when "Janela::Frame" then model.where(owner: ActsAsTenant.current_tenant)
      else model.all # acts_as_tenant has already scoped your own models
      end
    end

    def janela_frame_owner
      ActsAsTenant.current_tenant
    end
end
```

## With CanCanCan, or with your own

The same adapter, pointed at whatever you use:

```ruby
def policy_scope(model)
  model.accessible_by(current_ability)
end
```

Janela never asks how the answer was arrived at. A method that takes a
class and returns a relation is the whole contract.

## With one tenant

Write the answer anyway, once:

```ruby
class ApplicationController < ActionController::Base
  private
    def policy_scope(model) = model.all
end
```

Janela will not guess this one. Every other question here takes silence
as an answer, because the silent answer is the narrow one: no owner, no
theme, no tenancy. This question's permissive answer is the widest thing
a library can assume, so it is the one you have to say out loud (ADR
032).

The line is not ceremony either. It asserts that everyone who can reach
a dashboard may read every row behind it, and "one tenant" and "no rows
worth hiding from staff" are not the same claim. If the second is not
true here, return something narrower.

A frame is still created with a nil owner, because nothing is filtering
on one.

## What owns a frame

`Janela::Frame belongs_to :owner, polymorphic: true, optional: true`.
It can point at an account, a team, a user or anything else you scope
by, and Janela reads nothing from it. It exists so your scope has a
column.

Return the tenant from `janela_frame_owner` and the engine assigns it
to a frame it creates. Skip that method while your scope filters by
owner and the analyst's new dashboard is saved with no owner, then
hidden by your own policy the instant it is saved. It looks like the
save failed silently. `bin/rails janela:doctor` reports this for you:
it asks your policy for a scope over frames and looks for an owner in
what comes back.

## Snapshots are the rough edge

`janela_snapshots` has no owner column. A snapshot is a name, an
instant, the filters it was taken under and the results. So a multi
tenant application has to scope it by something else:

- Keep snapshots to one tenant, or to whoever publishes.
- Add your own column with a migration on `janela_snapshots` and scope
  on that.
- Encode the tenant in the filters a snapshot is taken under, and
  scope on the stored name.

None of those is as clean as a frame's owner. Giving a snapshot the
same polymorphic owner is [issue #32](https://github.com/retail-tasker/janela/issues/32).

## Proving your wiring

Run the doctor first. It reads your application and reports the traps
that are visible from outside a request:

```bash
bin/rails janela:doctor
```

Then write the test that matters, which is the one that fails if a
scope is ever loosened. Create a frame as one tenant and ask for it as
another:

```ruby
test "another tenant's frame is a 404" do
  frame = Janela::Frame.create!(name: "Theirs", owner: accounts(:acme))

  sign_in users(:globex_analyst)
  get janela.frame_path(frame)

  assert_response :not_found
end
```

This repository's dummy application is a worked example of all of the
above, in
[test/dummy/app/controllers/application_controller.rb](https://github.com/retail-tasker/janela/blob/main/test/dummy/app/controllers/application_controller.rb),
scoped by a `?tenant=` parameter standing in for a session.

## What Janela will never do

Add a tenant filter of its own. Your scope is the only one, so there
is nothing to double filter and nothing that looks enforced while
being unenforceable. Janela can be handed any relation through `on:`,
so a guarantee made here would be a guarantee it cannot keep.
