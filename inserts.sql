TRUNCATE historia_paczki, paczki, osoby, uzytkownicy, oddzialy, statusy, adresy, wojewodztwa RESTART IDENTITY CASCADE;

INSERT INTO statusy (nazwa, opis) VALUES 
('Nadana', 'Paczka zarejestrowana'),
('W oddziale', 'Paczka w oddziale docelowym'),
('W drodze', 'Transport między oddziałami'),
('Przekazana kurierowi', 'Wydana do doręczenia'),
('Doręczone', 'Dostarczona do klienta'),
('Odbiorca nieobecny', 'Awizo'),
('Przekazano do punktu', 'Odbiór w punkcie');

INSERT INTO wojewodztwa (nazwa) VALUES 
('Mazowieckie'), ('Małopolskie'), ('Śląskie');

INSERT INTO oddzialy (id_wojewodztwa, nazwa, typ, kod_min, kod_max) VALUES 
(1, 'Sortownia Centralna Warszawa', 'sortownia',        '00-000', '99-999'),

(2, 'Oddział Doręczeń Kraków',  'oddzial_doreczen', '30-000', '32-999'),

(3, 'Oddział Doręczeń Katowice','oddzial_doreczen', '40-000', '42-999');


INSERT INTO uzytkownicy (login, haslo, rola, czy_aktywny) VALUES 
('admin', '123', 'admin', true),
('klient', '123', 'klient', true);

INSERT INTO uzytkownicy (login, haslo, rola, id_oddzialu, czy_aktywny) VALUES 
('sort', '123', 'sortowacz', 1, true);

INSERT INTO uzytkownicy (login, haslo, rola, id_oddzialu, czy_aktywny) VALUES 
('magazyn', '123', 'magazynier', 2, true);

INSERT INTO uzytkownicy (login, haslo, rola, id_oddzialu, czy_aktywny) VALUES 
('kurier', '123', 'kurier', 2, true);

INSERT INTO uzytkownicy (login, haslo, rola, id_oddzialu, czy_aktywny) VALUES 
('maciej', '123', 'kurier', 2, true);

INSERT INTO adresy (miejscowosc, ulica, nr_domu, nr_lokalu, kod_pocztowy) VALUES 
('Warszawa', 'Wiejska', '1', NULL, '00-909'),
('Kraków',   'Smocza',  '5', NULL, '30-001'),
('Katowice', 'Spodek',  '1', NULL, '40-001');

INSERT INTO osoby (imie, nazwisko, telefon, adres, id_uzytkownika) VALUES 
('Adam', 'Nadawalski', '111111111', 1, (SELECT id_uzytkownika FROM uzytkownicy WHERE login='klient')),
('Beata', 'Krakowska', '222222222', 2, (SELECT id_uzytkownika FROM uzytkownicy WHERE login='klient')),
('Cezary', 'Katowicki','333333333', 3, (SELECT id_uzytkownika FROM uzytkownicy WHERE login='klient')),

('Jan', 'Kowalski', '997997997', 2, (SELECT id_uzytkownika FROM uzytkownicy WHERE login='kurier')),

('Maciej', 'Nowak', '998998998', 2, (SELECT id_uzytkownika FROM uzytkownicy WHERE login='maciej'));

INSERT INTO paczki (id_nadawcy, id_odbiorcy, id_adres_odbiorcy, id_aktualny_oddzial, id_aktualny_status, masa, dlugosc, szerokosc, wysokosc) 
VALUES (1, 2, 2, 1, (SELECT id_status FROM statusy WHERE nazwa='Nadana'), 2, 10, 10, 10);

INSERT INTO paczki (id_nadawcy, id_odbiorcy, id_adres_odbiorcy, id_aktualny_oddzial, id_aktualny_status, masa, dlugosc, szerokosc, wysokosc) 
VALUES (1, 3, 3, 1, (SELECT id_status FROM statusy WHERE nazwa='Nadana'), 5, 20, 20, 20);

INSERT INTO paczki (id_nadawcy, id_odbiorcy, id_adres_odbiorcy, id_aktualny_oddzial, id_aktualny_status, masa, dlugosc, szerokosc, wysokosc) 
VALUES (1, 2, 2, 2, (SELECT id_status FROM statusy WHERE nazwa='W oddziale'), 5, 30, 30, 30);

INSERT INTO paczki (id_nadawcy, id_odbiorcy, id_adres_odbiorcy, id_aktualny_oddzial, id_aktualny_status, id_kurier, masa, dlugosc, szerokosc, wysokosc) 
VALUES (1, 2, 2, 2, 4,
(SELECT id_uzytkownika FROM uzytkownicy WHERE login='kurier'), 
1, 15, 15, 15);

INSERT INTO paczki (id_nadawcy, id_odbiorcy, id_adres_odbiorcy, id_aktualny_oddzial, id_aktualny_status, id_kurier, masa, dlugosc, szerokosc, wysokosc) 
VALUES (1, 2, 2, 2, 5,
(SELECT id_uzytkownika FROM uzytkownicy WHERE login='kurier'), 
10, 50, 40, 30);

INSERT INTO historia_paczki (id_paczki, status, id_oddzialu, data) VALUES 
(5, 1, 1, NOW() - INTERVAL '3 days'),
(5, 2, 2, NOW() - INTERVAL '2 days'),
(5, 4, 2, NOW() - INTERVAL '1 day'),
(5, 5, 2, NOW());