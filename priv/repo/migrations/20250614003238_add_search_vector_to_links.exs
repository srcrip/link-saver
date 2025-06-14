defmodule LinkSaver.Repo.Migrations.AddSearchVectorToLinks do
  use Ecto.Migration

  def change do
    # Add tsvector column for full-text search
    alter table(:links) do
      add :search_vector, :tsvector
    end

    # Create GIN index for fast full-text searches
    create index(:links, [:search_vector], using: :gin)

    # Create function to update search vector
    execute """
    CREATE OR REPLACE FUNCTION update_link_search_vector()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.url, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.site_name, '')), 'D');
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """, """
    DROP FUNCTION IF EXISTS update_link_search_vector();
    """

    # Create trigger to automatically update search vector
    execute """
    CREATE TRIGGER update_link_search_vector_trigger
      BEFORE INSERT OR UPDATE OF title, description, url, site_name
      ON links
      FOR EACH ROW
      EXECUTE FUNCTION update_link_search_vector();
    """, """
    DROP TRIGGER IF EXISTS update_link_search_vector_trigger ON links;
    """

    # Update existing records
    execute """
    UPDATE links SET search_vector = 
      setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
      setweight(to_tsvector('english', COALESCE(description, '')), 'B') ||
      setweight(to_tsvector('english', COALESCE(url, '')), 'C') ||
      setweight(to_tsvector('english', COALESCE(site_name, '')), 'D');
    """
  end
end
