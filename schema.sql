CREATE OR REPLACE FUNCTION public.log_historia_paczki() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.id_aktualny_status IS DISTINCT FROM OLD.id_aktualny_status OR NEW.id_aktualny_oddzial IS DISTINCT FROM OLD.id_aktualny_oddzial) THEN
            INSERT INTO historia_paczki (id_paczki, status, data, id_oddzialu)
            VALUES (NEW.id_paczki, NEW.id_aktualny_status, NOW(), NEW.id_aktualny_oddzial);
        END IF;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO historia_paczki (id_paczki, status, data, id_oddzialu)
        VALUES (NEW.id_paczki, NEW.id_aktualny_status, NOW(), NEW.id_aktualny_oddzial);
    END IF;
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.log_historia_paczki() OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.trg_przypisanie_kuriera() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obecny_oddzial_kuriera INTEGER;
BEGIN
    IF NEW.id_kurier IS DISTINCT FROM OLD.id_kurier AND NEW.id_kurier IS NOT NULL THEN
        SELECT id_oddzialu INTO obecny_oddzial_kuriera 
        FROM uzytkownicy 
        WHERE id_uzytkownika = NEW.id_kurier;

        IF obecny_oddzial_kuriera <> NEW.id_aktualny_oddzial THEN
            RAISE EXCEPTION 'Error: kurier pracuje w % a paczka jest w %', 
                            obecny_oddzial_kuriera, NEW.id_aktualny_oddzial;
        END IF;
        
        NEW.id_aktualny_status := 4; 
    END IF;
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.trg_przypisanie_kuriera() OWNER TO postgres;


CREATE TABLE public.wojewodztwa (
    id_wojewodztwa integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nazwa text NOT NULL UNIQUE
);

CREATE TABLE public.adresy (
    id_adres integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    miejscowosc text NOT NULL,
    ulica text NOT NULL,
    nr_domu text NOT NULL,
    nr_lokalu text,
    kod_pocztowy character varying(6) NOT NULL,
    CONSTRAINT adresy_kod_pocztowy_check CHECK (kod_pocztowy ~ '^[0-9]{2}-[0-9]{3}$')
);

CREATE TABLE public.statusy (
    id_status integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nazwa text NOT NULL UNIQUE,
    opis text
);

CREATE TABLE public.oddzialy (
    id_oddzialu integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_wojewodztwa integer NOT NULL REFERENCES public.wojewodztwa(id_wojewodztwa) ON UPDATE CASCADE ON DELETE RESTRICT,
    nazwa text NOT NULL,
    typ text NOT NULL CHECK (typ IN ('sortownia', 'oddzial_doreczen')),
    kod_min character varying(6) NOT NULL CHECK (kod_min ~ '^[0-9]{2}-[0-9]{3}$'),
    kod_max character varying(6) NOT NULL CHECK (kod_max ~ '^[0-9]{2}-[0-9]{3}$'),
    CONSTRAINT check_zakres CHECK (kod_min <= kod_max)
);

CREATE TABLE public.uzytkownicy (
    id_uzytkownika integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    login text NOT NULL,
    haslo text NOT NULL,
    rola text NOT NULL CHECK (rola IN ('admin', 'magazynier', 'sortowacz', 'kurier', 'klient')),
    id_oddzialu integer REFERENCES public.oddzialy(id_oddzialu) ON UPDATE CASCADE ON DELETE RESTRICT,
    czy_aktywny boolean DEFAULT true NOT NULL
);

CREATE TABLE public.osoby (
    id_osoby integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    imie text NOT NULL,
    nazwisko text NOT NULL,
    telefon text NOT NULL CHECK (telefon ~ '^\+?[0-9]{7,15}$'),
    adres integer NOT NULL REFERENCES public.adresy(id_adres) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_uzytkownika integer NOT NULL REFERENCES public.uzytkownicy(id_uzytkownika) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE public.paczki (
    id_paczki integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_nadawcy integer NOT NULL REFERENCES public.osoby(id_osoby) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_odbiorcy integer NOT NULL REFERENCES public.osoby(id_osoby) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_adres_odbiorcy integer NOT NULL REFERENCES public.adresy(id_adres) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_kurier integer REFERENCES public.uzytkownicy(id_uzytkownika) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_aktualny_oddzial integer NOT NULL REFERENCES public.oddzialy(id_oddzialu) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_aktualny_status integer NOT NULL REFERENCES public.statusy(id_status) ON UPDATE CASCADE ON DELETE RESTRICT,
    masa integer,
    dlugosc integer,
    szerokosc integer,
    wysokosc integer,
    CONSTRAINT check_wymiary CHECK (dlugosc <= 64 AND szerokosc <= 41 AND wysokosc <= 38)
);

CREATE TABLE public.historia_paczki (
    id_wpisu integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_paczki integer NOT NULL REFERENCES public.paczki(id_paczki) ON UPDATE CASCADE ON DELETE RESTRICT,
    status integer NOT NULL REFERENCES public.statusy(id_status) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_oddzialu integer REFERENCES public.oddzialy(id_oddzialu) ON UPDATE CASCADE ON DELETE RESTRICT,
    data timestamp without time zone DEFAULT now()
);


CREATE VIEW public.widok_historii_paczki AS
 SELECT hp.id_paczki,
    s.nazwa AS status,
    COALESCE(o.nazwa, 'W trasie / u kuriera') AS lokalizacja,
    hp.data
   FROM historia_paczki hp
     JOIN statusy s ON hp.status = s.id_status
     LEFT JOIN oddzialy o ON hp.id_oddzialu = o.id_oddzialu
  ORDER BY hp.data DESC;

CREATE VIEW public.widok_klienta AS
 SELECT DISTINCT p.id_paczki,
    o_nad.imie || ' ' || o_nad.nazwisko AS "Nadawca",
    o_odb.imie || ' ' || o_odb.nazwisko AS "Odbiorca",
    a.miejscowosc || ', ' || a.ulica || ' ' || a.nr_domu ||
        CASE WHEN a.nr_lokalu IS NOT NULL AND a.nr_lokalu <> '' THEN '/' || a.nr_lokalu ELSE '' END AS "Adres Dostawy",
    s.nazwa AS "Status",
    o_nad.id_uzytkownika AS id_uzytkownika_nadawcy
   FROM paczki p
     JOIN osoby o_nad ON p.id_nadawcy = o_nad.id_osoby
     JOIN osoby o_odb ON p.id_odbiorcy = o_odb.id_osoby
     JOIN adresy a ON p.id_adres_odbiorcy = a.id_adres
     JOIN statusy s ON p.id_aktualny_status = s.id_status;

CREATE VIEW public.widok_kuriera AS
 SELECT p.id_paczki,
    s.nazwa AS aktualny_status,
    a.miejscowosc || ', ' || a.ulica || ' ' || a.nr_domu ||
        CASE WHEN a.nr_lokalu IS NOT NULL AND a.nr_lokalu <> '' THEN '/' || a.nr_lokalu ELSE '' END AS "Adres Dostawy",
    o.imie || ' ' || o.nazwisko AS "Odbiorca",
    o.telefon AS numer_telefonu,
    p.id_kurier,
    s.nazwa AS "Status"
   FROM paczki p
     JOIN statusy s ON p.id_aktualny_status = s.id_status
     JOIN adresy a ON p.id_adres_odbiorcy = a.id_adres
     JOIN osoby o ON p.id_odbiorcy = o.id_osoby;

CREATE VIEW public.widok_magazynier AS
 SELECT p.id_paczki,
    s.nazwa AS aktualny_status,
    o.id_oddzialu
   FROM paczki p
     JOIN oddzialy o ON p.id_aktualny_oddzial = o.id_oddzialu
     JOIN statusy s ON p.id_aktualny_status = s.id_status
     JOIN adresy a ON p.id_adres_odbiorcy = a.id_adres
  WHERE p.id_kurier IS NULL;

CREATE VIEW public.widok_sortowacz AS
 SELECT p.id_paczki,
    s.nazwa AS aktualny_status,
    o.id_oddzialu,
    a.kod_pocztowy
   FROM paczki p
     JOIN oddzialy o ON p.id_aktualny_oddzial = o.id_oddzialu
     JOIN statusy s ON p.id_aktualny_status = s.id_status
     JOIN adresy a ON p.id_adres_odbiorcy = a.id_adres;

CREATE VIEW widok_sugerowane_oddzialy AS
SELECT 
    p.id_paczki,
    o.id_oddzialu,
    o.nazwa AS nazwa_oddzialu
FROM paczki p
JOIN adresy a ON p.id_adres_odbiorcy = a.id_adres
JOIN oddzialy o ON
    a.kod_pocztowy >= o.kod_min AND 
    a.kod_pocztowy <= o.kod_max
WHERE o.typ = 'oddzial_doreczen';

CREATE TRIGGER trg_historia_paczki 
AFTER INSERT OR UPDATE ON public.paczki 
FOR EACH ROW EXECUTE FUNCTION public.log_historia_paczki();

CREATE TRIGGER trigger_auto_kurier 
BEFORE UPDATE ON public.paczki 
FOR EACH ROW EXECUTE FUNCTION public.trg_przypisanie_kuriera();