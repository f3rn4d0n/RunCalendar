import Foundation

extension Calendar {

    /// El calendario de la app: como el del sistema, pero con la semana **de lunes a domingo**.
    ///
    /// `Calendar.current` toma el primer día de la región, y en la de Fernando (`en_MX`) es el
    /// **domingo**. Eso hacía que la app y el atleta llevaran calendarios distintos: para él el
    /// domingo cierra la semana y para la app la abría. Se filtraba a todo lo que ordena días —
    /// la tirada larga, que va en la última posición, caía en sábado; y "el domingo la semana ya
    /// acabó" era falso desde el punto de vista del plan.
    ///
    /// Lunes fijo y no configurable: es la convención de los planes de entrenamiento (la semana
    /// termina con la tirada larga del fin de semana) y una preferencia más que nadie pidió.
    ///
    /// **Úsalo en todo lo que hable de "la semana"**: límites (`dateInterval(of: .weekOfYear)`),
    /// agrupaciones (`yearForWeekOfYear`) y posiciones. Para lo demás —`isDateInToday`,
    /// `component(.weekday,)`, aritmética de días— `Calendar.current` da igual: `firstWeekday`
    /// no las afecta.
    ///
    /// ponytail: se deriva de `current` en cada acceso en vez de cachearse, para no quedarse con
    /// una zona horaria vieja si el sistema cambia a media sesión.
    static var app: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2   // lunes
        return calendar
    }
}
