import streamlit as st
import psycopg2
from psycopg2 import extras
import pandas as pd


def get_connection():
    return psycopg2.connect(dbname="projekt", user="postgres", password="admin", host="localhost")


def execute_query(query, params=None, fetch=True):
    with get_connection() as conn:
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
            cur.execute(query, params)
            if fetch: return cur.fetchall()
            conn.commit()


def get_status_id(nazwa):
    res = execute_query("SELECT id_status FROM statusy WHERE nazwa = %s", (nazwa,))
    return res[0]['id_status'] if res else None


def display_table(data, hide_cols):
    if data:
        df = pd.DataFrame(data).drop(columns=hide_cols, errors='ignore')
        st.dataframe(df, use_container_width=True)
        return df
    st.info("Brak paczek do wyświetlenia.")
    return pd.DataFrame()


def view_klient(user):
    st.title("📦 Panel Klienta")
    u_id = user['id_uzytkownika']
    dane = execute_query("SELECT * FROM widok_klienta WHERE id_uzytkownika_nadawcy = %s", (u_id,))
    df = pd.DataFrame(dane) if dane else pd.DataFrame()
    
    tab1, tab2 = st.tabs(["🚀 W dostawie", "✅ Doręczone"])
    
    with tab1:
        if not df.empty:
            df_akt = df[df['Status'] != 'Doręczone']
            display_table(df_akt.to_dict('records'), ['id_uzytkownika_nadawcy'])
            
            with st.expander("🔍 Szczegóły i historia paczki (w drodze)"):
                wybrana = st.selectbox("Wybierz numer paczki", df_akt['id_paczki'].tolist(), key="n_akt")
                h = execute_query("SELECT status, lokalizacja, data FROM widok_historii_paczki WHERE id_paczki = %s",
                                  (wybrana,))
                if h: st.table(pd.DataFrame(h))
        else:
            st.info("Brak aktywnych paczek.")
    
    with tab2:
        if not df.empty:
            df_old = df[df['Status'] == 'Doręczone']
            display_table(df_old.to_dict('records'), ['id_uzytkownika_nadawcy'])
            with st.expander("📜 Zobacz historyczną drogę Twojej paczki"):
                wybrana_old = st.selectbox("Wybierz archiwalny numer", df_old['id_paczki'].tolist(), key="n_old")
                h_old = execute_query(
                    "SELECT status, lokalizacja, data FROM widok_historii_paczki WHERE id_paczki = %s", (wybrana_old,))
                if h_old: st.table(pd.DataFrame(h_old))
        else:
            st.info("Brak historii doręczeń.")
    
    st.divider()
    
    st.subheader("🚀 Nadaj nową paczkę")
    with st.form("form_paczka", clear_on_submit=True):
        
        col_nadawca, col_odbiorca = st.columns(2)
        with col_nadawca:
            st.markdown("### 📤 Nadawca (Skąd)")
            n_imie = st.text_input("Imię nadawcy")
            n_naz = st.text_input("Nazwisko nadawcy")
            n_tel = st.text_input("Telefon nadawcy")
            
            st.markdown("**Adres nadania:**")
            n_miasto = st.text_input("Miejscowość (Nadawca)")
            n_ulica = st.text_input("Ulica (Nadawca)")
            c1, c2 = st.columns(2)
            n_dom = c1.text_input("Nr domu (N)")
            n_lokal = c2.text_input("Nr lokalu (N)")
            n_kod = st.text_input("Kod pocztowy (Nadawca)")
        with col_odbiorca:
            st.markdown("### 📥 Odbiorca (Dokąd)")
            o_imie = st.text_input("Imię odbiorcy")
            o_naz = st.text_input("Nazwisko odbiorcy")
            o_tel = st.text_input("Telefon odbiorcy")
            st.markdown("**Adres dostawy:**")
            o_miasto = st.text_input("Miejscowość (Odbiorca)")
            o_ulica = st.text_input("Ulica (Odbiorca)")
            c3, c4 = st.columns(2)
            o_dom = c3.text_input("Nr domu (O)")
            o_lokal = c4.text_input("Nr lokalu (O)")
            o_kod = st.text_input("Kod pocztowy (Odbiorca)")
            st.divider()
        
        st.markdown("### 📦 Parametry paczki")
        col_p1, col_p2, col_p3, col_p4 = st.columns(4)
        
        with col_p1:
            masa = st.number_input("Masa (kg)", min_value=1, max_value=15, step=1, value=1, help="Max 15kg")
        with col_p2:
            dlugosc = st.number_input("Długość (cm)", min_value=1, max_value=64, step=1, help="Max 64cm")
        with col_p3:
            szerokosc = st.number_input("Szerokość (cm)", min_value=1, max_value=41, step=1, help="Max 41cm")
        with col_p4:
            wysokosc = st.number_input("Wysokość (cm)", min_value=1, max_value=38, step=1, help="Max 38cm")

        st.divider()
        
        if st.form_submit_button("Zatwierdź i wyślij"):
            required = [n_imie, n_naz, n_miasto, n_ulica, n_dom, n_kod,
                        o_imie, o_naz, o_miasto, o_ulica, o_dom, o_kod]
            
            if not all(required):
                st.error("Wypełnij wszystkie wymagane pola (dla nadawcy i odbiorcy)!")
            else:
                try:
                    with get_connection() as conn:
                        cur = conn.cursor()
                        def przetworz_osobe_i_adres(imie, nazw, tel, miasto, ulica, dom, lokal, kod):
                            val_lokal = lokal if lokal and lokal.strip() != "" else None
                            
                            cur.execute("""
                                SELECT id_adres FROM adresy
                                WHERE miejscowosc=%s AND ulica=%s AND nr_domu=%s AND kod_pocztowy=%s
                                AND (nr_lokalu=%s OR (nr_lokalu IS NULL AND %s IS NULL))
                            """, (miasto, ulica, dom, kod, val_lokal, val_lokal))
                            
                            adres_row = cur.fetchone()
                            if adres_row:
                                adr_id = adres_row[0]
                            else:
                                cur.execute(
                                    "INSERT INTO adresy (miejscowosc, ulica, nr_domu, nr_lokalu, kod_pocztowy) VALUES (%s,%s,%s,%s,%s) RETURNING id_adres",
                                    (miasto, ulica, dom, val_lokal, kod))
                                adr_id = cur.fetchone()[0]
                            
                            cur.execute("""
                                SELECT id_osoby FROM osoby
                                WHERE imie=%s AND nazwisko=%s AND telefon=%s AND adres=%s AND id_uzytkownika=%s
                            """, (imie, nazw, tel, adr_id, u_id))
                            
                            osoba_row = cur.fetchone()
                            if osoba_row:
                                os_id = osoba_row[0]
                            else:
                                cur.execute(
                                    "INSERT INTO osoby (imie, nazwisko, telefon, adres, id_uzytkownika) VALUES (%s,%s,%s,%s,%s) RETURNING id_osoby",
                                    (imie, nazw, tel, adr_id, u_id))
                                os_id = cur.fetchone()[0]
                            
                            return os_id, adr_id
                        
                        id_nadawcy, id_adresu_nadawcy = przetworz_osobe_i_adres(
                            n_imie, n_naz, n_tel, n_miasto, n_ulica, n_dom, n_lokal, n_kod
                        )
                        
                        id_odbiorcy, id_adresu_odbiorcy = przetworz_osobe_i_adres(
                            o_imie, o_naz, o_tel, o_miasto, o_ulica, o_dom, o_lokal, o_kod
                        )
                        
                        cur.execute(
                            "INSERT INTO paczki (id_nadawcy, id_odbiorcy, id_adres_odbiorcy, id_aktualny_oddzial, id_aktualny_status) VALUES (%s,%s,%s,(SELECT id_oddzialu FROM oddzialy LIMIT 1),(SELECT id_status FROM statusy WHERE nazwa='Nadana' LIMIT 1))",
                            (id_nadawcy, id_odbiorcy, id_adresu_odbiorcy))
                        
                        conn.commit()
                    st.success("Paczka została pomyślnie nadana!")
                    st.rerun()
                except Exception as e:
                    st.error(f"Błąd bazy danych: {e}")


def view_kurier(user):
    st.header("🚚 Panel Kuriera")
    dane = execute_query("SELECT * FROM widok_kuriera WHERE id_kurier = %s AND aktualny_status != 'Doręczone'",
                         (user['id_uzytkownika'],))

    c1, c2 = st.columns([2, 1])
    with c1:
        df = display_table(dane, ['id_kurier'])
    with c2:
        if not df.empty:
            pid = st.selectbox("Wybierz paczkę", df['id_paczki'])
            stat = st.selectbox("Zmień status", ["Doręczone", "Odbiorca nieobecny", "Przekazano do punktu"])
            if st.button("Aktualizuj status"):
                execute_query("UPDATE paczki SET id_aktualny_status = %s WHERE id_paczki = %s",
                              (get_status_id(stat), pid), False)
                st.toast(f"Paczka {pid} zaktualizowana!")
                st.rerun()


def view_magazynier(user):
    st.header("🏢 Panel Magazyniera")
    dane = execute_query("SELECT * FROM widok_magazynier WHERE id_oddzialu = %s", (user['id_oddzialu'],))
    
    c1, c2 = st.columns([2, 1])
    with c1:
        df = display_table(dane, ['id_oddzialu'])
    with c2:
        if not df.empty:
            pid = st.selectbox("Paczka do przypisania", df['id_paczki'])
            
            kurierzy = execute_query(
                "SELECT u.id_uzytkownika, o.imie, o.nazwisko FROM uzytkownicy u JOIN osoby o ON u.id_uzytkownika = o.id_uzytkownika WHERE u.rola = 'kurier' AND u.id_oddzialu = %s AND u.czy_aktywny = TRUE",
                (user['id_oddzialu'],))
            
            if kurierzy:
                m_k = {f"{k['imie']} {k['nazwisko']}": k['id_uzytkownika'] for k in kurierzy}
                sel_k = st.selectbox("Wybierz kuriera", list(m_k.keys()))
                
                if st.button("Przypisz do kuriera"):
                    try:
                        execute_query(
                            "UPDATE paczki SET id_kurier = %s WHERE id_paczki = %s",
                            (m_k[sel_k], pid),
                            False
                        )
                        st.success("Paczka przekazana kurierowi!")
                        st.rerun()
                    
                    except Exception as e:
                        st.error(f"Nie udało się przypisać: {e}")
            else:
                st.warning("Brak aktywnych kurierów w Twoim oddziale.")


def view_sortowacz(user):
    st.header("⚙️ Panel Sortowacza")
    dane = execute_query("SELECT * FROM widok_sortowacz WHERE id_oddzialu = %s", (user['id_oddzialu'],))
    
    c1, c2 = st.columns([2, 1])
    with c1:
        df = display_table(dane, ['id_oddzialu'])
    with c2:
        if not df.empty:
            pid = st.selectbox("Paczka do wysłania", df['id_paczki'])
            
            oddz = execute_query(
                "SELECT id_oddzialu, nazwa_oddzialu FROM widok_sugerowane_oddzialy WHERE id_paczki = %s", (pid,))
            
            m_o = {o['nazwa_oddzialu']: o['id_oddzialu'] for o in oddz}
            
            if m_o:
                sel_o = st.selectbox("Wybierz oddział docelowy", list(m_o.keys()))
                if st.button("Wyślij paczkę"):
                    execute_query(
                        "UPDATE paczki SET id_aktualny_oddzial = %s, id_aktualny_status = %s WHERE id_paczki = %s",
                        (m_o[sel_o], get_status_id('W oddziale'), pid), False)
                    st.success("Paczka w drodze do oddziału!")
                    st.rerun()
            else:
                st.warning("⚠️ Brak oddziału obsługującego ten kod pocztowy.")


def main():
    st.set_page_config(page_title="System Kurierski", layout="wide")

    if 'user' not in st.session_state: st.session_state.user = None

    if not st.session_state.user:
        st.header("🔐 Logowanie")
        l, p = st.text_input("Login"), st.text_input("Hasło", type="password")
        if st.button("Zaloguj"):
            res = execute_query("SELECT * FROM uzytkownicy WHERE login=%s AND haslo=%s AND czy_aktywny = TRUE", (l, p))
            if res:
                st.session_state.user = res[0]
                st.rerun()
            else:
                st.error("Błędny login, hasło lub konto jest nieaktywne.")
    else:
        st.sidebar.title(f"👤 {st.session_state.user['login']}")
        st.sidebar.write(f"Rola: **{st.session_state.user['rola']}**")
        if st.sidebar.button("Wyloguj"):
            st.session_state.user = None
            st.rerun()

        roles = {
            'klient': view_klient,
            'kurier': view_kurier,
            'magazynier': view_magazynier,
            'sortowacz': view_sortowacz
        }
        roles.get(st.session_state.user['rola'], lambda u: st.error("Nieznana rola"))(st.session_state.user)


if __name__ == "__main__":
    main()