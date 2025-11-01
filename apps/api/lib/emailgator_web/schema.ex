defmodule EmailgatorWeb.Schema do
  use Absinthe.Schema

  import_types(EmailgatorWeb.Schema.Types)

  query do
    field :me, :user do
      resolve(&EmailgatorWeb.Schema.Resolvers.User.me/3)
    end

    field :categories, list_of(:category) do
      resolve(&EmailgatorWeb.Schema.Resolvers.Category.list/3)
    end

    field :category, :category do
      arg(:id, non_null(:id))
      resolve(&EmailgatorWeb.Schema.Resolvers.Category.get/3)
    end

    field :accounts, list_of(:account) do
      resolve(&EmailgatorWeb.Schema.Resolvers.Account.list/3)
    end

    field :category_emails, list_of(:email) do
      arg(:category_id, non_null(:id))
      resolve(&EmailgatorWeb.Schema.Resolvers.Email.list_by_category/3)
    end
  end

  mutation do
    field :create_category, :category do
      arg(:name, non_null(:string))
      arg(:description, :string)

      resolve(&EmailgatorWeb.Schema.Resolvers.Category.create/3)
    end

    field :update_category, :category do
      arg(:id, non_null(:id))
      arg(:name, :string)
      arg(:description, :string)

      resolve(&EmailgatorWeb.Schema.Resolvers.Category.update/3)
    end

    field :delete_category, :category do
      arg(:id, non_null(:id))
      resolve(&EmailgatorWeb.Schema.Resolvers.Category.delete/3)
    end

    field :connect_account, :account do
      arg(:email, non_null(:string))
      arg(:access_token, non_null(:string))
      arg(:refresh_token, non_null(:string))
      arg(:expires_at, :datetime)

      resolve(&EmailgatorWeb.Schema.Resolvers.Account.connect/3)
    end

    field :disconnect_account, :account do
      arg(:id, non_null(:id))
      resolve(&EmailgatorWeb.Schema.Resolvers.Account.disconnect/3)
    end

    field :delete_emails, list_of(:id) do
      arg(:email_ids, non_null(list_of(non_null(:id))))
      resolve(&EmailgatorWeb.Schema.Resolvers.Email.bulk_delete/3)
    end

    field :unsubscribe_emails, list_of(:unsubscribe_result) do
      arg(:email_ids, non_null(list_of(non_null(:id))))
      resolve(&EmailgatorWeb.Schema.Resolvers.Email.bulk_unsubscribe/3)
    end
  end
end
